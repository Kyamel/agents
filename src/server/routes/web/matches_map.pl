:- module(route_matches_map, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/json)).
:- use_module('../../../engine/engine').
:- use_module('../../../services/matches').
:- use_module('../../views/page').
:- use_module('../../views/match_detail', [render_not_found/1]).
:- use_module('../../views/match_map_data').
:- use_module('../../views/match_map_page').
:- use_module('../../views/agent_link').

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

render_map(Request, Id) :-
    matches:find_match(Id, Match),
    !,
    render_map_page(Request, Match).
render_map(Request, _Id) :-
    render_not_found(Request).

render_map_page(Request, Match) :-
    matches:decode_replay(Match.replay_json, Replay),
    match_map_data:map_data(Match.scenario, Replay, Data),
    atom_json_dict(DataJson, Data, [width(0)]),
    matches:agent_display_name(Match.thief_agent_id, ThiefName),
    matches:agent_display_name(Match.detective_agent_id, DetectiveName),
    agent_link:agent_link(Match.thief_agent_id, ThiefName, ThiefLink),
    agent_link:agent_link(
        Match.detective_agent_id,
        DetectiveName,
        DetectiveLink
    ),
    engine:scenario_text(Match.scenario, MapName),
    atom_concat('/matches/', Match.id, DetailLink),
    match_map_page:content(
        MapName,
        ThiefLink,
        DetectiveLink,
        DetailLink,
        DataJson,
        Content
    ),
    page:reply_page(
        Request,
        'Mapa da partida',
        Content,
        [width(wide)]
    ).
