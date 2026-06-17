:- module(api_matches_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/json)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../db/db').

% Prefix em /api/v1/matches/ para capturar o ID. /api/v1/matches (sem barra)
% tem handler proprio (lista) e ganha pela especificidade.
:- http_handler('/api/v1/matches/', handler,
                [methods([get, options]), prefix]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, Request) :-
    memberchk(path(Path), Request),
    handle_get(Path).

handle_get(Path) :-
    extract_id(Path, Id),
    !,
    load_match(Id, Status, Payload),
    reply_json(Status, Payload).
handle_get(_) :-
    reply_json(404, _{error: "not_found"}).

extract_id(Path, Id) :-
    atom_concat('/api/v1/matches/', Id, Path),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_match(Id, 200, _{match: Json}) :-
    db:get_match(Id, Match),
    !,
    match_with_replay(Match, Json).
load_match(_, 404, _{error: "match_not_found"}).

% Decodifica o replay JSON persistido e o anexa ao dict da partida.
match_with_replay(Match, Match.put(replay, Replay)) :-
    catch(atom_json_dict(Match.replay_json, Replay, []), _, fail),
    !.
match_with_replay(Match, Match).
