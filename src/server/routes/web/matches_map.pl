:- module(route_matches_map, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/json)).
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
        script([src('/assets/match_map.js')], [])
    ]).

% Grafo do cenario, ou listas vazias se for desconhecido/ilegivel (ex.:
% partidas antigas sem o caminho do cenario).
graph_for(Scenario, Cities, Edges) :-
    catch(engine:scenario_graph(Scenario, Cities, Edges), _, fail),
    !.
graph_for(_Scenario, [], []).

map_start(Setup, Thief, Detective) :-
    ( get_dict(thief_start, Setup, Thief0) -> Thief = Thief0 ; Thief = null ),
    ( get_dict(detective_start, Setup, Det0) -> Detective = Det0 ; Detective = null ).

% Projeta o turno do replay para o frame consumido pelo JS.
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

% Controles play/slider/intervalo; o JS liga tudo pelos ids `mm-*`.
map_controls(Html) :-
    ui:surface_class('p-4 mb-4 flex flex-wrap items-center gap-3', CardClass),
    ui:text_class(meta,
                  'font-mono text-surface-300 min-w-[5rem] text-center',
                  TurnClass),
    ui:text_class(meta,
                  'text-surface-400 flex items-center gap-2 ml-auto',
                  IntervalClass),
    Html = div([class(CardClass)], [
        button([type(button), id('mm-play'),
                class('rounded-lg bg-ufop-600 px-4 py-2 font-semibold \c
                       hover:bg-ufop-500')], 'Reproduzir'),
        input([type(range), id('mm-slider'), min(0), max(0), value(0), step(1),
               class('flex-1 accent-ufop-500')]),
        span([id('mm-turn-label'), class(TurnClass)],
             'Início'),
        label([class(IntervalClass)], [
            'Intervalo',
            input([type(number), id('mm-interval'), value(800), min(100),
                   step(100),
                   class('w-24 rounded-lg bg-surface-800 border border-surface-700 \c
                          px-2 py-1 text-surface-200')]),
            'ms'
        ])
    ]).

map_legend(Html) :-
    ui:text_class(meta, 'flex items-center gap-5 mb-4', Class),
    Html = div([class(Class)], [
        span([class('flex items-center gap-2')], [
            span([class('inline-block w-3 h-3 rounded-full bg-amber-400')], []),
            'Rota do ladrão'
        ]),
        span([class('flex items-center gap-2')], [
            span([class('inline-block w-3 h-3 rounded-full bg-sky-400')], []),
            'Rota do detetive'
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
