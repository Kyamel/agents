:- module(api_jobs_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../engine/match_queue').
:- use_module('../../../db/sqlite_store').

% Detalhe de um job pelo id da partida. Se o job ainda esta ativo, devolve o
% estado em memoria (com elapsed_seconds em tempo real); se ja terminou, cai no
% estado persistido em `matches` (status final, elapsed nulo).
:- http_handler('/api/v1/jobs/', handler, [methods([get, options]), prefix]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, Request) :-
    memberchk(path(Path), Request),
    handle_get(Path).

handle_get(Path) :-
    extract_id(Path, Id),
    !,
    load_job(Id, Status, Payload),
    reply_json(Status, Payload).
handle_get(_) :-
    reply_json(404, _{error: "not_found"}).

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
