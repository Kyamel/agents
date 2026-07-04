:- module(route_matches_map, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/json)).
:- use_module(library(pairs)).
:- use_module('../../../engine/engine').
:- use_module('../../../services/matches').
:- use_module('../../views/page').
:- use_module('../../views/match_detail', [render_not_found/1]).
:- use_module('../../views/page_section').
:- use_module('../../views/ui').

:- http_handler('/map/', handler, [method(get), prefix]).

handler(Request) :-
    memberchk(path(Path), Request),
    extract_id(Path, Id),
    !,
    render_map(Request, Id).
handler(Request) :-
    http_redirect(see_other, '/matches', Request).

extract_id(Path, Id) :-
    atom_concat('/map/', Id, Path),
    Id \== ''.

replay_field(Replay, Key, _Default, Value) :-
    get_dict(Key, Replay, Value),
    !.
replay_field(_Replay, _Key, Default, Default).

% =============================
% Mapa interativo da partida (/map/<id>)
% =============================

render_map(Request, Id) :-
    matches:find_match(Id, Match),
    !,
    render_map_page(Request, Match).
render_map(Request, _Id) :-
    render_not_found(Request).

% Serializa o grafo do cenario e as posicoes turno-a-turno como JSON e delega
% o desenho/animacao ao asset estatico /assets/match_map.js.
render_map_page(Request, Match) :-
    matches:decode_replay(Match.replay_json, Replay),
    replay_field(Replay, setup, _{}, Setup),
    replay_field(Replay, turns, [], Turns),
    graph_for(Match.scenario, Cities, Edges),
    map_start(Setup, StartThief, StartDetective, LockMode, Appearance),
    map_objective(Match.scenario, Setup, Objective),
    map_loot(Match.scenario, Loot),
    maplist(map_turn_frame, Turns, TurnFrames),
    Data = _{
        cities: Cities,
        edges: Edges,
        start: _{
            thief: StartThief,
            detective: StartDetective,
            blocked: [],
            lock_mode: LockMode,
            appearance: Appearance
        },
        objective: Objective,
        loot: Loot,
        turns: TurnFrames,
        winner: Match.winner
    },
    atom_json_dict(DataJson, Data, [width(0)]),
    matches:agent_display_name(Match.thief_agent_id, ThiefName),
    matches:agent_display_name(Match.detective_agent_id, DetectiveName),
    engine:scenario_text(Match.scenario, MapName),
    atom_concat('/matches/', Match.id, DetailLink),
    page_section:back_link(DetailLink, 'Voltar para a partida', BackLink),
    map_controls(Controls),
    map_legend(Legend),
    map_event_card(EventInfo),
    map_scroll_card(
        amber,
        'Aparência do ladrão',
        'Original e valor apresentado atualmente; em azul, o traço real \c
         revelado ao detetive por um furto; em violeta, um disfarce revelado',
        'mm-appearance',
        'space-y-2 overflow-y-auto min-h-0 flex-1 pr-1',
        AppearanceCard
    ),
    map_scroll_card(
        emerald,
        'Itens coletados',
        'Tesouros e itens que o ladrão já roubou até este turno',
        'mm-collected',
        'flex flex-wrap content-start gap-2 overflow-y-auto min-h-0 flex-1 pr-1',
        CollectedCard
    ),
    map_state_card(
        sky,
        'Mandato do detetive',
        'Último mandato válido durante a partida',
        'mm-mandate',
        MandateCard
    ),
    map_replay_layout(AppearanceCard, CollectedCard, ReplayLayout),
    ui:text_class(title, 'mt-3 mb-1', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-5', DescriptionClass),
    page:reply_page(Request, 'Mapa da partida', [
        BackLink,
        h1([class(TitleClass)], 'Mapa da partida'),
        p([class(DescriptionClass)], [
            'Mapa: ', b([], MapName),
            '  •  Ladrão: ', b([], ThiefName),
            '  •  Detetive: ', b([], DetectiveName)
        ]),
        Legend,
        Controls,
        ReplayLayout,
        % Evento e Mandato lado a lado, com a mesma altura.
        div([class('grid gap-4 mb-4 lg:grid-cols-2 lg:items-stretch')], [
            EventInfo, MandateCard
        ]),
        script([type('application/json'), id('match-map-data')], DataJson),
        script([src('/assets/match_map.js?v=17')], [])
    ], [width(wide)]).

% Grafo do cenario, ou listas vazias se for desconhecido/ilegivel (ex.:
% partidas antigas sem o caminho do cenario).
graph_for(Scenario, Cities, Edges) :-
    catch(engine:scenario_graph(Scenario, Cities, Edges), _, fail),
    !.
graph_for(_Scenario, [], []).

map_start(Setup, Thief, Detective, LockMode, Appearance) :-
    replay_field(Setup, thief_start, null, Thief),
    replay_field(Setup, detective_start, null, Detective),
    replay_field(Setup, lock_mode, "accumulate", LockMode),
    replay_field(Setup, appearance, [], Appearance).

map_objective(Scenario, Setup, Objective) :-
    get_dict(target, Setup, Target),
    engine:scenario_treasure(Scenario, Target, City, Requirements),
    !,
    Objective = _{
        city: City,
        requirements: Requirements
    }.
map_objective(_, _, _{city: null, requirements: []}).

% Itens e tesouros do cenario com a cidade de origem, para o JS marcar no mapa
% e mover para a lista de coletados quando forem roubados. Lista vazia se o
% cenario for desconhecido/ilegivel.
map_loot(Scenario, LootDicts) :-
    scenario_loot_safe(Scenario, Loot),
    maplist(loot_dict, Loot, LootDicts).

% Loot do cenario, ou lista vazia se ele for desconhecido/ilegivel.
scenario_loot_safe(Scenario, Loot) :-
    catch(engine:scenario_loot(Scenario, Loot), _, fail),
    !.
scenario_loot_safe(_Scenario, []).

loot_dict(loot(Kind, Name, City), Dict) :-
    atom_string(Kind, KindText),
    city_text(Name, NameText),
    city_text(City, CityText),
    Dict = _{
        kind: KindText,
        name: NameText,
        city: CityText
    }.

% Projeta o turno do replay para o frame consumido pelo JS.
map_turn_frame(Turn, Frame) :-
    get_dict(turn, Turn, N),
    get_dict(thief_position, Turn, ThiefPos),
    get_dict(detective_position, Turn, DetPos),
    get_dict(thief_action, Turn, ThiefAction),
    get_dict(detective_action, Turn, DetAction),
    replay_field(Turn, thief_status, "", ThiefStatus),
    replay_field(Turn, detective_status, "", DetStatus),
    replay_field(Turn, events, [], Events),
    robbery_details(Events, StolenItems, RobberyCities, RobberyEvents),
    map_disguise_effect(ThiefAction, ThiefStatus, DisguiseEffect),
    map_mandate_effect(DetAction, DetStatus, MandateEffect),
    map_inspection(DetAction, DetStatus, Inspection),
    map_lock_effect(DetAction, DetStatus, LockEffect, LockCity),
    Frame = _{
        turn: N,
        thief_pos: ThiefPos,
        detective_pos: DetPos,
        thief_action: ThiefAction,
        thief_status: ThiefStatus,
        detective_action: DetAction,
        detective_status: DetStatus,
        disguise_effect: DisguiseEffect,
        mandate_effect: MandateEffect,
        inspection: Inspection,
        lock_effect: LockEffect,
        lock_city: LockCity,
        stolen_items: StolenItems,
        robbery_cities: RobberyCities,
        robbery_events: RobberyEvents
    }.

robbery_details(Events, Items, Cities, Robberies) :-
    include(robbery_event, Events, Robberies),
    findall(Item-City,
            ( member(Event, Robberies),
              get_dict(item, Event, Item),
              get_dict(city, Event, City)
            ),
            Pairs),
    pairs_keys_values(Pairs, Items, Cities).

robbery_event(Event) :-
    get_dict(type, Event, "robbery").

map_disguise_effect(ActionText, Status, Effect) :-
    status_ok(Status),
    action_term(ActionText, disfarce(Changes)),
    is_list(Changes),
    !,
    maplist(disguise_change, Changes, ChangeDicts),
    Effect = _{type: "apply", changes: ChangeDicts}.
map_disguise_effect(ActionText, Status, _{type: "remove", changes: []}) :-
    status_ok(Status),
    action_term(ActionText, despir_disfarce),
    !.
map_disguise_effect(_, _, _{type: "none", changes: []}).

disguise_change(trocar(Original, Current), Change) :-
    !,
    city_text(Original, OriginalText),
    city_text(Current, CurrentText),
    Change = _{
        type: "replace",
        original: OriginalText,
        current: CurrentText
    }.
disguise_change(omitir(Original), Change) :-
    !,
    city_text(Original, OriginalText),
    Change = _{
        type: "omit",
        original: OriginalText,
        current: null
    }.
disguise_change(adicionar(Current), Change) :-
    !,
    city_text(Current, CurrentText),
    Change = _{
        type: "add",
        original: null,
        current: CurrentText
    }.
disguise_change(Other, Change) :-
    city_text(Other, Text),
    Change = _{
        type: "unknown",
        original: Text,
        current: Text
    }.

map_mandate_effect(ActionText, Status, Effect) :-
    status_ok(Status),
    action_term(ActionText, pedir_mandato(Suspect, Clues)),
    is_list(Clues),
    !,
    maplist(city_text, Clues, ClueTexts),
    Effect = _{
        type: "set",
        suspect: Suspect,
        clues: ClueTexts
    }.
map_mandate_effect(_, _, _{
    type: "none",
    suspect: null,
    clues: []
}).

map_inspection(ActionText, Status, true) :-
    status_ok(Status),
    action_term(ActionText, inspecionar),
    !.
map_inspection(_, _, false).

% Converte as acoes validas do detetive em efeitos simples para o JavaScript.
% O JavaScript aplica esses efeitos conforme a versao da engine registrada no
% setup. Replays antigos acumulavam bloqueios; a engine atual mantem apenas um.
map_lock_effect(ActionText, Status, "close", CityText) :-
    status_ok(Status),
    action_term(ActionText, fechar(City)),
    !,
    city_text(City, CityText).
map_lock_effect(ActionText, Status, "open", CityText) :-
    status_ok(Status),
    action_term(ActionText, liberar(City)),
    !,
    city_text(City, CityText).
map_lock_effect(_, _, "none", null).

status_ok("OK").
status_ok('OK').

action_term(Term, Term) :-
    compound(Term),
    !.
action_term(Text, Term) :-
    string(Text),
    catch(term_string(Term, Text), _, fail),
    !.
action_term(Atom, Term) :-
    atom(Atom),
    catch(atom_to_term(Atom, Term, _), _, fail).

city_text(City, Text) :-
    atom(City),
    !,
    atom_string(City, Text).
city_text(City, City) :-
    number(City),
    !.
city_text(City, Text) :-
    term_string(City, Text).

% Controles play/slider/intervalo; o JS liga tudo pelos ids `mm-*`.
map_controls(Html) :-
    ui:surface_class('p-4 mb-4 flex flex-wrap items-center gap-3', CardClass),
    ui:text_class(meta,
                  'font-mono text-surface-300 min-w-[5rem] text-center',
                  TurnClass),
    ui:text_class(meta,
                  'text-surface-400 flex items-center gap-2 ml-auto',
                  IntervalClass),
    ui:primary_button_class(
        'inline-flex h-10 w-10 shrink-0 items-center justify-center \c
         rounded-lg p-0 font-mono text-xl leading-none',
        PlayClass
    ),
    Html = div([class(CardClass)], [
        button([type(button), id('mm-play'), class(PlayClass),
                'aria-label'('Reproduzir'), title('Reproduzir')], [
            span([id('mm-play-icon'), 'aria-hidden'(true),
                  class('block'), style('transform: translateY(-1px)')], '▶︎')
        ]),
        input([type(range), id('mm-slider'), min(0), max(0), value(0), step(1),
               class('flex-1 accent-ufop-500')]),
        span([id('mm-turn-label'), class(TurnClass)],
             'Início'),
        label([class(IntervalClass)], [
            'Intervalo',
            input([type(number), id('mm-interval'), value(500), min(100),
                   step(100),
                   class('w-24 rounded-lg bg-surface-800 border border-surface-600 \c
                          px-2 py-1 text-surface-200')]),
            'ms'
        ])
    ]).

% Layout responsivo do replay. `map-wide` fica definido na configuracao global
% do Tailwind (page.pl), mantendo o breakpoint especial de 1440px centralizado.
map_replay_layout(AppearanceCard, CollectedCard, Html) :-
    ui:surface_class(
        'overflow-hidden order-first lg:order-none',
        GraphClass
    ),
    Html = div([class('grid gap-4 mb-4 lg:items-start \c
                       lg:grid-cols-[minmax(16rem,_20rem)_minmax(0,_1fr)] \c
                       xl:grid-cols-[minmax(0,_1fr)_56rem] \c
                       map-wide:grid-cols-[minmax(0,_1fr)_56rem_minmax(0,_1fr)]')], [
        AppearanceCard,
        div([id('mm-graph'), class(GraphClass)], []),
        div([class('min-w-0 lg:col-span-2 map-wide:col-span-1')],
            [CollectedCard])
    ]).

map_legend(Html) :-
    ui:text_class(
        meta,
        'grid grid-cols-2 gap-x-3 gap-y-2 mb-4 \c
         sm:flex sm:flex-wrap sm:items-center sm:gap-x-5 sm:gap-y-2',
        Class
    ),
    Html = div([class(Class)], [
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('inline-block shrink-0 w-3 h-3 rounded-full bg-amber-400')], []),
            'Rota do ladrão'
        ]),
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('inline-block shrink-0 w-3 h-3 rounded-full bg-sky-400')], []),
            'Rota do detetive'
        ]),
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('inline-block shrink-0 w-3 h-3 rounded bg-red-500')], []),
            'Cidade bloqueada'
        ]),
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('inline-block shrink-0 w-3 h-3 rounded bg-emerald-500')], []),
            'Objetivo liberado'
        ]),
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('inline-block shrink-0 w-3 h-3 rounded bg-amber-400')], []),
            'Evento de furto'
        ]),
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('shrink-0')], '\x1f48e\'),
            'Tesouro na cidade'
        ]),
        span([class('min-w-0 flex items-center gap-2 leading-tight')], [
            span([class('shrink-0')], '\x1f4e6\'),
            'Item na cidade'
        ])
    ]).

map_event_card(Html) :-
    ui:tinted_card_class(amber, CardClass),
    ui:eyebrow_class(amber, AccentClass),
    ui:text_class(meta,
                  'font-mono mt-1 break-words whitespace-pre-line',
                  InfoClass),
    Html = div([class(CardClass)], [
        p([class(AccentClass)], 'Evento'),
        p([id('mm-event'), class(InfoClass)], '-')
    ]).

% Card com cabecalho fixo e area de conteudo rolavel (ContentClass define o
% layout interno). A altura total leva a classe `js-map-height`; o JS detecta
% pela posicao renderizada quando o card esta ao lado do mapa e sincroniza ambos.
map_scroll_card(Accent, Label, Description, Id, ContentClass, Html) :-
    ui:eyebrow_class(Accent, AccentClass),
    ui:surface_class('p-4 flex flex-col overflow-hidden js-map-height', CardClass),
    ui:text_class(meta, 'text-surface-400 mt-1 mb-3 shrink-0', DescriptionClass),
    Html = div([class(CardClass)], [
        p([class(AccentClass)], Label),
        p([class(DescriptionClass)], Description),
        div([id(Id), class(ContentClass)], [])
    ]).

map_state_card(Accent, Label, Description, Id, Html) :-
    ui:eyebrow_class(Accent, AccentClass),
    ui:surface_class('p-4', CardClass),
    ui:text_class(meta, 'text-surface-400 mt-1 mb-3', DescriptionClass),
    Html = div([class(CardClass)], [
        p([class(AccentClass)], Label),
        p([class(DescriptionClass)], Description),
        div([id(Id), class('space-y-2')], [])
    ]).
