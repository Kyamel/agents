:- module(api_matches_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/json)).
:- use_module('../../security/rate_limit').
:- use_module('../../../db/sqlite_store').

% Prefix em /api/v1/matches/ para capturar o ID. /api/v1/matches (sem barra)
% tem handler proprio (lista) e ganha pela especificidade.
:- http_handler('/api/v1/matches/', handler,
                [methods([get, options]), prefix]).

% =============================
% Handler
% =============================

handler(Request) :-
    cors_enable(Request, [methods([get, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    memberchk(path(Path), Request),
    dispatch(Method, Path).

dispatch(options, _) :-
    format("Content-type: text/plain~n~n").
dispatch(get, Path) :-
    extract_id(Path, Id),
    !,
    load_match(Id, Status, Payload),
    reply(Status, Payload).
dispatch(get, _) :-
    reply(404, _{error: "not_found"}).
dispatch(_, _) :-
    reply(405, _{error: "method_not_allowed"}).

extract_id(Path, Id) :-
    atom_concat('/api/v1/matches/', Id, Path),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_match(Id, 200, _{match: Json}) :-
    sqlite_store:get_match(Id, Match),
    !,
    match_with_replay(Match, Json).
load_match(_, 404, _{error: "match_not_found"}).

% Decodifica o replay JSON persistido e o anexa ao dict da partida.
match_with_replay(Match, Json) :-
    (   catch(atom_json_dict(Match.replay_json, Replay, []), _, fail)
    ->  Json = Match.put(replay, Replay)
    ;   Json = Match
    ).

% =============================
% Resposta (JSON)
% =============================

reply(Status, Payload) :-
    reply_json_dict(Payload, [status(Status)]).
