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
    map_start(Setup, StartThief, StartDetective, LockMode),
    map_objective(Match.scenario, Setup, Objective),
    maplist(map_turn_frame, Turns, TurnFrames),
    Data = _{
        cities: Cities,
        edges: Edges,
        start: _{
            thief: StartThief,
            detective: StartDetective,
            blocked: [],
            lock_mode: LockMode
        },
        objective: Objective,
        turns: TurnFrames,
        winner: Match.winner
    },
    atom_json_dict(DataJson, Data, [width(0)]),
    matches:agent_display_name(Match.thief_agent_id, ThiefName),
    matches:agent_display_name(Match.detective_agent_id, DetectiveName),
    atom_concat('/matches/', Match.id, DetailLink),
    page_section:back_link(DetailLink, 'Voltar para a partida', BackLink),
    map_controls(Controls),
    map_legend(Legend),
    map_info_card('mm-thief', amber, 'Ladrão', ThiefInfo),
    map_info_card('mm-detective', sky, 'Detetive', DetectiveInfo),
    ui:surface_class('mb-6 overflow-hidden', GraphClass),
    ui:text_class(title, 'mt-3 mb-1', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-5', DescriptionClass),
    page:reply_page(Request, 'Mapa da partida', [
        BackLink,
        h1([class(TitleClass)], 'Mapa da partida'),
        p([class(DescriptionClass)], [
            'Ladrão: ', b([], ThiefName), '  •  Detetive: ', b([], DetectiveName)
        ]),
        Legend,
        Controls,
        div([id('mm-graph'), class(GraphClass)], []),
        div([id('mm-info'), class('grid sm:grid-cols-2 gap-4')], [
            ThiefInfo, DetectiveInfo
        ]),
        script([type('application/json'), id('match-map-data')], DataJson),
        script([src('/assets/match_map.js?v=5')], [])
    ]).

% Grafo do cenario, ou listas vazias se for desconhecido/ilegivel (ex.:
% partidas antigas sem o caminho do cenario).
graph_for(Scenario, Cities, Edges) :-
    catch(engine:scenario_graph(Scenario, Cities, Edges), _, fail),
    !.
graph_for(_Scenario, [], []).

map_start(Setup, Thief, Detective, LockMode) :-
    ( get_dict(thief_start, Setup, Thief0) -> Thief = Thief0 ; Thief = null ),
    ( get_dict(detective_start, Setup, Det0) -> Detective = Det0 ; Detective = null ),
    replay_field(Setup, lock_mode, "accumulate", LockMode).

map_objective(Scenario, Setup, Objective) :-
    get_dict(target, Setup, Target),
    engine:scenario_treasure(Scenario, Target, City, Requirements),
    !,
    Objective = _{
        city: City,
        requirements: Requirements
    }.
map_objective(_, _, _{city: null, requirements: []}).

% Projeta o turno do replay para o frame consumido pelo JS.
map_turn_frame(Turn, Frame) :-
    get_dict(turn, Turn, N),
    get_dict(thief_position, Turn, ThiefPos),
    get_dict(detective_position, Turn, DetPos),
    get_dict(thief_action, Turn, ThiefAction),
    get_dict(detective_action, Turn, DetAction),
    replay_field(Turn, detective_status, "", DetStatus),
    replay_field(Turn, events, [], Events),
    robbery_details(Events, StolenItems, RobberyCities),
    map_lock_effect(DetAction, DetStatus, LockEffect, LockCity),
    Frame = _{
        turn: N,
        thief_pos: ThiefPos,
        detective_pos: DetPos,
        thief_action: ThiefAction,
        detective_action: DetAction,
        detective_status: DetStatus,
        lock_effect: LockEffect,
        lock_city: LockCity,
        stolen_items: StolenItems,
        robbery_cities: RobberyCities
    }.

robbery_details(Events, Items, Cities) :-
    findall(Item-City,
            ( member(Event, Events),
              get_dict(type, Event, "robbery"),
              get_dict(item, Event, Item),
              get_dict(city, Event, City)
            ),
            Pairs),
    pairs_keys_values(Pairs, Items, Cities).

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
    ui:primary_button_class('rounded-lg px-4 py-2', PlayClass),
    Html = div([class(CardClass)], [
        button([type(button), id('mm-play'), class(PlayClass)], 'Reproduzir'),
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
        ])
    ]).

map_info_card(Id, Accent, Label, Html) :-
    ui:eyebrow_class(Accent, AccentClass),
    ui:surface_class('p-4', CardClass),
    ui:text_class(meta,
                  'font-mono text-surface-300 mt-1 break-all',
                  InfoClass),
    Html = div([class(CardClass)], [
        p([class(AccentClass)], Label),
        p([id(Id), class(InfoClass)], '-')
    ]).
