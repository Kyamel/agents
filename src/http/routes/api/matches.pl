:- module(api_matches, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/json)).
:- use_module('../../security/rate_limit').
:- use_module('../../controller/matches_orchestrator').
:- use_module('../../../db/sqlite_store', [get_match/2]).

:- http_handler(root(api/v1/matches), matches_handler,
                [prefix, methods([get, post, options])]).

%!  matches_handler(+Request) is det.
%
%   Ponto de entrada da API de partidas; despacha colecao e recurso individual.
matches_handler(Request) :-
    cors_enable(Request, [methods([get, post, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    memberchk(path(Path), Request),
    matches_route(Path, Method, Request).

%!  matches_route(+Path, +Method, +Request) is det.
%
%   Separa `/api/v1/matches` (colecao) de `/api/v1/matches/<id>` (recurso).
matches_route('/api/v1/matches', Method, Request) :-
    !,
    matches_collection(Method, Request).
matches_route(Path, Method, Request) :-
    atom_concat('/api/v1/matches/', Id, Path),
    Id \== '',
    !,
    match_resource(Id, Method, Request).
matches_route(_, _, _) :-
    reply_json_dict(_{error: "not_found"}, [status(404)]).

%!  matches_collection(+Method, +Request) is det.
%
%   Operacoes de listagem e execucao de partidas.
matches_collection(options, _) :-
    format("Content-type: text/plain~n~n").
matches_collection(get, _Request) :-
    matches_orchestrator:list_matches(Matches),
    reply_json_dict(_{matches: Matches}).
matches_collection(post, Request) :-
    matches_orchestrator:create_match_from_request(Request, Payload),
    reply_json_dict(Payload, [status(201)]).
matches_collection(_, _) :-
    reply_json_dict(_{error: "method_not_allowed"}, [status(405)]).

%!  match_resource(+Id, +Method, +Request) is det.
%
%   Operacoes sobre uma partida especifica.
match_resource(_, options, _) :-
    !,
    format("Content-type: text/plain~n~n").
match_resource(Id, get, _Request) :-
    !,
    (   sqlite_store:get_match(Id, Match)
    ->  match_with_replay(Match, Json),
        reply_json_dict(_{match: Json})
    ;   reply_json_dict(_{error: "match_not_found"}, [status(404)])
    ).
match_resource(_, _, _) :-
    reply_json_dict(_{error: "method_not_allowed"}, [status(405)]).

%!  match_with_replay(+Match, -Json) is det.
%
%   Decodifica o replay JSON persistido e o anexa ao dict da partida.
match_with_replay(Match, Json) :-
    (   catch(atom_json_dict(Match.replay_json, Replay, []), _, fail)
    ->  Json = Match.put(replay, Replay)
    ;   Json = Match
    ).
