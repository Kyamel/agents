:- module(route_matches_map, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/json)).
:- use_module('../../db/sqlite_store').
:- use_module('../../engine/match_runner').
:- use_module('../../components/page').
:- use_module('../../components/match_detail', [render_not_found/1]).
:- use_module('../../components/page_section').

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
% Mapa interativo da partida (/map/<id>)
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
