:- module(api_matches_show, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../../services/matches').

path(root(api/v1/matches/Id), [id-Id]).
accept(get, none).

handle(get, _Request, _User, Params, Outcome) :-
    load_match(Params.id, Outcome).

render(_Request, match(Json), json(200, _{match: Json})).
render(_Request, not_found,   json(404, _{error: "match_not_found"})).

% Anexa o replay decodificado ao dict da partida; `{}` quando ausente/corrompido.
load_match(Id, match(Json)) :-
    matches:find_match(Id, Match),
    !,
    matches:decode_replay(Match.replay_json, Replay),
    Json = Match.put(replay, Replay).
load_match(_, not_found).

:- api_endpoint:mount(api_matches_show).
