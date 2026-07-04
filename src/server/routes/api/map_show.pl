:- module(api_map_show, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../../services/matches').
:- use_module('../../views/match_map_data').

path(root(api/v1/map/Id), [id-Id]).
accept(get, none).

handle(get, _Request, _User, Params, Outcome) :-
    load_map(Params.id, Outcome).

render(_Request, map(Data), json(200, Data)).
render(_Request, not_found, json(404, _{error: "match_not_found"})).

load_map(Id, map(Data)) :-
    matches:find_match(Id, Match),
    !,
    matches:decode_replay(Match.replay_json, Replay),
    match_map_data:map_data(Match.scenario, Replay, Data).
load_map(_, not_found).

:- api_endpoint:mount(api_map_show).
