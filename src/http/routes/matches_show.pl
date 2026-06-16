:- module(route_matches_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/json)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../engine/match_queue').
:- use_module('../../engine/match_runner').
:- use_module('../../components/page').
:- use_module('../../components/match_card').
:- use_module('../../components/page_section').
:- use_module('../../components/button_link').

% Prefix em /matches/ para capturar /matches/<id>. /matches/new tem handler
% proprio (mais especifico) e ganha por especificidade.
:- http_handler('/matches/', handler, [method(get), prefix]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(path(Path), Request),
    handle_path(Path, Request).

handle_path(Path, Request) :-
    extract_map_id(Path, Id),
    !,
    render_map(Request, Id).
handle_path(Path, Request) :-
    extract_id(Path, Id),
    !,
    load_and_render(Request, Id).
handle_path(_, Request) :-
    http_redirect(see_other, '/matches', Request).

extract_id(Path, Id) :-
    atom_concat('/matches/', Id, Path),
    Id \== '',
    Id \== new.

%!  extract_map_id(+Path, -Id) is semidet.
%
%   Casa /matches/<id>/map (visualizacao interativa). Precisa ser testado antes
%   de extract_id/2, que aceitaria "<id>/map" como id.
extract_map_id(Path, Id) :-
    atom_concat('/matches/', Rest, Path),
    atom_concat(Id, '/map', Rest),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_and_render(Request, Id) :-
    sqlite_store:get_match(Id, Match),
    !,
    render_for_status(Request, Id, Match).
load_and_render(Request, _) :-
    render_not_found(Request).

% Partida concluida: replay completo. Caso contrario (na fila/executando/falha):
% painel de status. A pagina nao atualiza sozinha; o usuario recarrega quando
% quiser pelo link "Atualizar".
render_for_status(Request, _Id, Match) :-
    Match.status == "done",
    !,
    render_done(Request, Match).
render_for_status(Request, Id, Match) :-
    match_queue:job_info(Id, Info),
    !,
    render_progress(Request, Match, Info.status, Info.elapsed_seconds).
render_for_status(Request, _Id, Match) :-
    render_progress(Request, Match, Match.status, "-").

render_done(Request, Match) :-
    agent_display_name(Match.thief_agent_id, ThiefName),
    agent_display_name(Match.detective_agent_id, DetectiveName),
    replay_data(Match.replay_json, Replay),
    render_detail(Request, Match, ThiefName, DetectiveName, Replay).

agent_display_name(AgentId, Name) :-
    sqlite_store:get_agent(AgentId, Agent),
    !,
    Name = Agent.name.
agent_display_name(AgentId, AgentId).

%!  replay_data(+ReplayJson, -Replay) is det.
%
%   Decodifica o replay para o dict `{turns, events, setup, ...}`. Cai num
%   dict vazio se o JSON estiver ausente ou corrompido.
replay_data(ReplayJson, Replay) :-
    catch(atom_json_dict(ReplayJson, Replay, []), _, fail),
    is_dict(Replay),
    !.
replay_data(_, _{}).

%!  replay_field(+Replay, +Key, +Default, -Value) is det.
replay_field(Replay, Key, _Default, Value) :-
    get_dict(Key, Replay, Value),
    !.
replay_field(_Replay, _Key, Default, Default).

% =============================
% Resposta (HTML)
% =============================

render_detail(Request, Match, ThiefName, DetectiveName, Replay) :-
    replay_field(Replay, turns, [], Turns),
    replay_field(Replay, events, [], Events),
    replay_field(Replay, setup, _{}, Setup),
    page_section:back_link('/matches', 'Voltar para partidas', BackLink),
    stat_card('Ladrao', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    winner_card(Match.winner, WinnerCard),
    setup_section(Setup, SetupHtml),
    events_section(Events, EventsHtml),
    turns_table(Turns, TableHtml),
    atom_concat('/matches/', Match.id, MatchPath),
    atom_concat(MatchPath, '/map', MapLink),
    button_link:button_link(MapLink, 'Visualizar mapa', MapButton),
    page:reply_page(Request, 'Detalhe da partida', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Detalhe da partida'),
        p([class('font-mono text-xs text-slate-500 mb-5 break-all')], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-6')], [
            ThiefCard, DetectiveCard, WinnerCard
        ]),
        div([class('mb-8')], [MapButton]),
        SetupHtml,
        EventsHtml,
        h2([class('font-semibold mb-3')], 'Replay turno a turno'),
        TableHtml
    ]).

% =============================
% Pagina de partida em andamento / falha
% =============================

%!  render_progress(+Request, +Match, +Status, +Elapsed) is det.
%
%   Painel para partidas que ainda nao concluiram (na fila/executando) ou que
%   falharam (timeout/erro). A pagina nao recarrega sozinha: ha um link
%   "Atualizar" para o usuario consultar o estado quando quiser.
render_progress(Request, Match, Status, Elapsed) :-
    agent_display_name(Match.thief_agent_id, ThiefName),
    agent_display_name(Match.detective_agent_id, DetectiveName),
    elapsed_text(Elapsed, ElapsedText),
    status_banner(Status, Banner),
    page_section:back_link('/matches', 'Voltar para partidas', BackLink),
    stat_card('Ladrao', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    stat_card('Tempo decorrido', ElapsedText, TimeCard),
    atom_concat('/matches/', Match.id, SelfLink),
    page:reply_page(Request, 'Partida em andamento', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Partida em andamento'),
        p([class('font-mono text-xs text-slate-500 mb-5 break-all')], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-8')], [
            ThiefCard, DetectiveCard, TimeCard
        ]),
        Banner,
        div([class('mt-4')], [
            a([href(SelfLink), class('text-ufop-400 hover:underline text-sm')],
              'Atualizar')
        ])
    ]).

%!  elapsed_text(+Elapsed, -Text) is det.
elapsed_text(Elapsed, Text) :-
    number(Elapsed),
    !,
    format(string(Text), "~w s", [Elapsed]).
elapsed_text(_Elapsed, "-").

%!  status_banner(+Status, -Html) is det.
status_banner(Status, Html) :-
    status_meta(Status, Title, Hint, Class),
    Html = div([class(Class)], [
        p([class('font-semibold')], Title),
        p([class('text-sm opacity-80 mt-1')], Hint)
    ]).

status_meta("queued", 'Na fila',
    'Aguardando um worker disponivel para iniciar a execucao.',
    'rounded-xl bg-amber-950 p-4 border border-amber-800 text-amber-200') :- !.
status_meta("running", 'Em execucao',
    'A engine esta processando esta partida.',
    'rounded-xl bg-sky-950 p-4 border border-sky-800 text-sky-200') :- !.
status_meta("timeout", 'Tempo esgotado',
    'A partida excedeu o limite de tempo e foi interrompida.',
    'rounded-xl bg-rose-950 p-4 border border-rose-800 text-rose-200') :- !.
status_meta("error", 'Falha na execucao',
    'Ocorreu um erro ao executar esta partida.',
    'rounded-xl bg-rose-950 p-4 border border-rose-800 text-rose-200') :- !.
status_meta(_Other, 'Status desconhecido',
    'O estado desta partida nao pode ser determinado.',
    'rounded-xl bg-slate-900 p-4 border border-slate-700 text-slate-200').

% =============================
% Mapa interativo da partida (/matches/<id>/map)
% =============================

render_map(Request, Id) :-
    sqlite_store:get_match(Id, Match),
    !,
    render_map_page(Request, Match).
render_map(Request, _Id) :-
    render_not_found(Request).

%!  render_map_page(+Request, +Match) is det.
%
%   Pagina de visualizacao interativa: serializa o grafo do cenario e as
%   posicoes turno-a-turno como JSON e delega o desenho/animacao ao asset
%   estatico /assets/match_map.js.
render_map_page(Request, Match) :-
    replay_data(Match.replay_json, Replay),
    replay_field(Replay, setup, _{}, Setup),
    replay_field(Replay, turns, [], Turns),
    graph_for(Match.scenario, Cities, Edges),
    map_start(Setup, StartThief, StartDetective),
    maplist(map_turn_frame, Turns, TurnFrames),
    Data = _{
        cities: Cities,
        edges: Edges,
        start: _{ thief: StartThief, detective: StartDetective },
        turns: TurnFrames,
        winner: Match.winner
    },
    atom_json_dict(DataJson, Data, [width(0)]),
    agent_display_name(Match.thief_agent_id, ThiefName),
    agent_display_name(Match.detective_agent_id, DetectiveName),
    atom_concat('/matches/', Match.id, DetailLink),
    page_section:back_link(DetailLink, 'Voltar para a partida', BackLink),
    map_controls(Controls),
    map_legend(Legend),
    map_info_card('mm-thief', amber, 'Ladrao', ThiefInfo),
    map_info_card('mm-detective', sky, 'Detetive', DetectiveInfo),
    page:reply_page(Request, 'Mapa da partida', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Mapa da partida'),
        p([class('text-slate-400 text-sm mb-5')], [
            'Ladrao: ', b([], ThiefName), '  •  Detetive: ', b([], DetectiveName)
        ]),
        Legend,
        Controls,
        div([id('mm-graph'),
             class('rounded-xl bg-slate-900 border border-slate-800 mb-6 \c
                    overflow-hidden')], []),
        div([id('mm-info'), class('grid sm:grid-cols-2 gap-4')], [
            ThiefInfo, DetectiveInfo
        ]),
        script([type('application/json'), id('match-map-data')], DataJson),
        script([src('/assets/match_map.js')], [])
    ]).

%!  graph_for(+Scenario, -Cities, -Edges) is det.
%
%   Grafo do cenario, ou listas vazias se o cenario for desconhecido/ilegivel
%   (ex.: partidas antigas sem o caminho do cenario).
graph_for(Scenario, Cities, Edges) :-
    catch(match_runner:scenario_graph(Scenario, Cities, Edges), _, fail),
    !.
graph_for(_Scenario, [], []).

%!  map_start(+Setup, -Thief, -Detective) is det.
map_start(Setup, Thief, Detective) :-
    ( get_dict(thief_start, Setup, Thief0) -> Thief = Thief0 ; Thief = null ),
    ( get_dict(detective_start, Setup, Det0) -> Detective = Det0 ; Detective = null ).

%!  map_turn_frame(+Turn, -Frame) is det.
%
%   Projeta o dict de um turno do replay para o frame consumido pelo JS: numero
%   do turno, posicoes (ou "-" quando o agente nao moveu) e o texto das acoes.
map_turn_frame(Turn, Frame) :-
    get_dict(turn, Turn, N),
    get_dict(thief_position, Turn, ThiefPos),
    get_dict(detective_position, Turn, DetPos),
    get_dict(thief_action, Turn, ThiefAction),
    get_dict(detective_action, Turn, DetAction),
    Frame = _{
        turn: N,
        thief_pos: ThiefPos,
        detective_pos: DetPos,
        thief_action: ThiefAction,
        detective_action: DetAction
    }.

%!  map_controls(-Html) is det.
%
%   Barra de controle: reproduzir/pausar, slider de turnos, rotulo do turno e
%   intervalo (ms) do modo automatico. O JS liga tudo pelos ids `mm-*`.
map_controls(Html) :-
    Html = div([class('rounded-xl bg-slate-900 border border-slate-800 p-4 mb-4 \c
                       flex flex-wrap items-center gap-3')], [
        button([type(button), id('mm-play'),
                class('rounded-lg bg-ufop-600 px-4 py-2 font-semibold \c
                       hover:bg-ufop-500')], 'Reproduzir'),
        input([type(range), id('mm-slider'), min(0), max(0), value(0), step(1),
               class('flex-1 accent-ufop-500')]),
        span([id('mm-turn-label'),
              class('font-mono text-sm text-slate-300 min-w-[5rem] text-center')],
             'Inicio'),
        label([class('text-sm text-slate-400 flex items-center gap-2 ml-auto')], [
            'Intervalo',
            input([type(number), id('mm-interval'), value(800), min(100),
                   step(100),
                   class('w-24 rounded-lg bg-slate-800 border border-slate-700 \c
                          px-2 py-1 text-slate-200')]),
            'ms'
        ])
    ]).

%!  map_legend(-Html) is det.
map_legend(div([class('flex items-center gap-5 mb-4 text-sm')], [
        span([class('flex items-center gap-2')], [
            span([class('inline-block w-3 h-3 rounded-full bg-amber-400')], []),
            'Ladrao'
        ]),
        span([class('flex items-center gap-2')], [
            span([class('inline-block w-3 h-3 rounded-full bg-sky-400')], []),
            'Detetive'
        ])
    ])).

%!  map_info_card(+Id, +Accent, +Label) is det.
map_info_card(Id, Accent, Label, Html) :-
    accent_text_class(Accent, AccentClass),
    Html = div([class('rounded-xl bg-slate-900 border border-slate-800 p-4')], [
        p([class(AccentClass)], Label),
        p([id(Id), class('font-mono text-sm text-slate-300 mt-1 break-all')], '-')
    ]).

accent_text_class(amber, 'text-amber-400 text-xs uppercase tracking-wide font-semibold').
accent_text_class(sky, 'text-sky-400 text-xs uppercase tracking-wide font-semibold').

% =============================
% Secao: configuracao da partida (setup)
% =============================

%!  setup_section(+Setup, -Html) is det.
%
%   Painel com os metadados iniciais da partida extraidos da engine.
setup_section(Setup, Html) :-
    field_text(Setup, scenario, Scenario),
    field_text(Setup, target, Target),
    field_text(Setup, max_turns, MaxTurns),
    field_text(Setup, thief_start, ThiefStart),
    field_text(Setup, detective_start, DetectiveStart),
    field_text(Setup, disguises, Disguises),
    fact('Cenario', Scenario, F1),
    fact('Alvo do ladrao', Target, F2),
    fact('Limite de turnos', MaxTurns, F3),
    fact('Inicio do ladrao', ThiefStart, F4),
    fact('Inicio do detetive', DetectiveStart, F5),
    fact('Disfarces disponiveis', Disguises, F6),
    appearance_chips(Setup, Chips),
    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800 mb-8')], [
        h2([class('font-semibold mb-4')], 'Configuracao da partida'),
        div([class('grid sm:grid-cols-3 gap-x-6 gap-y-4 text-sm')],
            [F1, F2, F3, F4, F5, F6]),
        div([class('mt-5')], [
            p([class('text-slate-500 text-xs uppercase tracking-wide mb-2')],
              'Aparencia do alvo'),
            div([class('flex flex-wrap gap-2')], Chips)
        ])
    ]).

fact(Label, Value, div([], [
        dt([class('text-slate-500 text-xs uppercase tracking-wide')], Label),
        dd([class('font-medium mt-0.5 break-all')], Value)
    ])).

appearance_chips(Setup, Chips) :-
    get_dict(appearance, Setup, Attrs),
    is_list(Attrs),
    Attrs \= [],
    !,
    maplist(chip, Attrs, Chips).
appearance_chips(_Setup, [span([class('text-slate-500 text-sm')], '-')]).

chip(Text, span([class('inline-block rounded-full bg-slate-800 text-slate-300 \c
                        px-3 py-1 text-xs')], Text)).

% =============================
% Secao: eventos do jogo (roubos)
% =============================

%!  events_section(+Events, -Html) is det.
%
%   Linha do tempo dos eventos relevantes (roubos) capturados na partida.
events_section([], Html) :-
    !,
    Html = div([class('mb-8')], [
        h2([class('font-semibold mb-3')], 'Eventos'),
        p([class('text-slate-500 text-sm')], 'Nenhum roubo registrado nesta partida.')
    ]).
events_section(Events, Html) :-
    maplist(event_item, Events, Items),
    Html = div([class('mb-8')], [
        h2([class('font-semibold mb-3')], 'Eventos'),
        ul([class('space-y-2')], Items)
    ]).

event_item(Event, Html) :-
    get_dict(type, Event, "robbery"),
    !,
    field_text(Event, turn, Turn),
    field_text(Event, item, Item),
    field_text(Event, city, City),
    revealed_text(Event, Revealed),
    format(string(Title), "Turno ~w: roubo de ~w em ~w", [Turn, Item, City]),
    Html = li([class('rounded-lg bg-amber-950/40 border border-amber-900/60 px-3 py-2')], [
        p([class('text-amber-200 text-sm font-medium')], Title),
        p([class('text-amber-200/70 text-xs mt-0.5')], Revealed)
    ]).
event_item(Event, Html) :-
    field_text(Event, turn, Turn),
    field_text(Event, detail, Detail),
    format(string(Text), "Turno ~w: ~w", [Turn, Detail]),
    Html = li([class('rounded-lg bg-slate-900 border border-slate-800 px-3 py-2 \c
                      text-slate-300 text-sm')], Text).

%!  revealed_text(+Event, -Text) is det.
%
%   Descreve as pistas (atributos) reveladas por um roubo.
revealed_text(Event, Text) :-
    get_dict(revealed, Event, Revealed),
    is_list(Revealed),
    Revealed \= [],
    !,
    atomic_list_concat(Revealed, ', ', Joined),
    format(string(Text), "Pistas reveladas: ~w", [Joined]).
revealed_text(_Event, "Sem novas pistas.").

%!  field_text(+Dict, +Key, -Text) is det.
%
%   Le um campo do dict como texto exibivel, com traco como fallback.
field_text(Dict, Key, Text) :-
    get_dict(Key, Dict, Value),
    !,
    format(string(Text), "~w", [Value]).
field_text(_Dict, _Key, "-").

stat_card(Label, Value, Html) :-
    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        p([class('text-slate-500 text-xs uppercase tracking-wide')], Label),
        p([class('font-semibold mt-1 break-all')], Value)
    ]).

winner_card(Winner, Html) :-
    match_card:winner_label(Winner, Text, _),
    winner_card_class(Winner, CardClass),
    Html = div([class(CardClass)], [
        p([class('text-xs uppercase tracking-wide opacity-80')], 'Resultado'),
        p([class('font-semibold mt-1')], Text)
    ]).

winner_card_class(thief, C) :- !, amber_card(C).
winner_card_class("thief", C) :- !, amber_card(C).
winner_card_class(detective, C) :- !, emerald_card(C).
winner_card_class("detective", C) :- !, emerald_card(C).
winner_card_class(_, 'rounded-xl bg-slate-900 p-4 border border-slate-700 text-slate-200').

amber_card('rounded-xl bg-amber-950 p-4 border border-amber-800 text-amber-200').
emerald_card('rounded-xl bg-emerald-950 p-4 border border-emerald-800 text-emerald-200').

turns_table([], Html) :-
    !,
    page_section:empty_state('Replay indisponivel para esta partida.', Html).
turns_table(Turns, Html) :-
    maplist(turn_row, Turns, Rows),
    Html = div([class('overflow-x-auto rounded-xl border border-slate-800')], [
        table([class('w-full text-sm')], [
            thead([class('bg-slate-900 text-slate-400')], [
                tr([], [
                    th([class('text-left px-3 py-2')], 'Turno'),
                    th([class('text-left px-3 py-2')], 'Acao ladrao'),
                    th([class('text-left px-3 py-2')], 'Pos. ladrao'),
                    th([class('text-left px-3 py-2')], 'Acao detetive'),
                    th([class('text-left px-3 py-2')], 'Pos. detetive')
                ])
            ]),
            tbody([], Rows)
        ])
    ]).

turn_row(Turn, tr([class('border-t border-slate-800')], [
        td([class('px-3 py-2 text-slate-400')], TurnNo),
        td([class(ThiefClass)], ThiefAction),
        td([class('px-3 py-2 text-slate-400')], ThiefPos),
        td([class(DetectiveClass)], DetectiveAction),
        td([class('px-3 py-2 text-slate-400')], DetectivePos)
    ])) :-
    field_text(Turn, turn, TurnNo),
    field_text(Turn, thief_action, ThiefAction),
    field_text(Turn, thief_position, ThiefPos),
    field_text(Turn, detective_action, DetectiveAction),
    field_text(Turn, detective_position, DetectivePos),
    action_class(Turn, thief_status, ThiefClass),
    action_class(Turn, detective_status, DetectiveClass).

%!  action_class(+Turn, +StatusKey, -Class) is det.
%
%   Acoes ilegais (rejeitadas pela engine) sao destacadas em vermelho.
action_class(Turn, StatusKey, 'px-3 py-2 text-rose-400') :-
    get_dict(StatusKey, Turn, "Ilegal"),
    !.
action_class(_Turn, _StatusKey, 'px-3 py-2').

render_not_found(Request) :-
    page:reply_page(Request, 'Partida nao encontrada', [
        h1([class('text-2xl font-bold mb-2')], 'Partida nao encontrada'),
        p([class('text-slate-400 mb-6')],
          'Nao existe partida com esse identificador.'),
        a([href('/matches'), class('text-ufop-400 hover:underline')],
          'Voltar para partidas')
    ]).
