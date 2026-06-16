:- module(api_jobs_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../../engine/match_queue').
:- use_module('../../../db/sqlite_store').

% Detalhe de um job pelo id da partida. Se o job ainda esta ativo, devolve o
% estado em memoria (com elapsed_seconds em tempo real); se ja terminou, cai no
% estado persistido em `matches` (status final, elapsed nulo).
:- http_handler('/api/v1/jobs/', handler, [methods([get, options]), prefix]).

handler(Request) :-
    cors_enable(Request, [methods([get, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    memberchk(path(Path), Request),
    dispatch(Method, Path).

dispatch(options, _) :-
    format("Content-type: text/plain~n~n").
dispatch(get, Path) :-
    handle_get(Path).
dispatch(_, _) :-
    reply_json_dict(_{error: "method_not_allowed"}, [status(405)]).

handle_get(Path) :-
    extract_id(Path, Id),
    !,
    load_job(Id, Status, Payload),
    reply_json_dict(Payload, [status(Status)]).
handle_get(_) :-
    reply_json_dict(_{error: "not_found"}, [status(404)]).

extract_id(Path, Id) :-
    atom_concat('/api/v1/jobs/', Id, Path),
    Id \== ''.

load_job(Id, 200, _{job: Info}) :-
    match_queue:job_info(Id, Info),
    !.
load_job(Id, 200, _{job: Info}) :-
    sqlite_store:get_match(Id, Match),
    !,
    match_to_job(Match, Info).
load_job(_, 404, _{error: "job_not_found"}).

%!  match_to_job(+Match, -Job) is det.
%
%   Representa uma partida ja finalizada no mesmo formato de um job ativo, para
%   que o cliente possa consultar o id ate o estado final aparecer.
match_to_job(Match, _{
    match_id: Match.id,
    status: Match.status,
    elapsed_seconds: null,
    pid: null,
    thief_id: Match.thief_agent_id,
    detective_id: Match.detective_agent_id,
    scenario: Match.scenario
}).
