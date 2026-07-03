:- module(jobs, [
    snapshot/1,
    find_job/2
]).

:- use_module('../db/db').
:- use_module('../engine/engine').

% Servico de jobs (partidas em execucao). Jobs nao tem tabela: o estado ativo
% vive em memoria no engine (fila + workers). Job ja terminado cai no estado
% persistido em `matches`.

%!  snapshot(-Jobs) is det.   Jobs ativos (fila + executando).
snapshot(Jobs) :-
    engine:job_snapshot(Jobs).

%!  find_job(+Id, -Outcome) is det.
%
%   Outcome:
%     - job(Info)   job ativo (engine) ou partida finalizada (matches)
%     - not_found
find_job(Id, job(Info)) :-
    engine:job_info(Id, Info),
    !.
find_job(Id, job(Info)) :-
    db:get_match(Id, Match),
    !,
    match_to_job(Match, Info).
find_job(_, not_found).

% Partida finalizada no mesmo formato de um job ativo (elapsed/pid nulos).
match_to_job(Match, _{
    match_id: Match.id,
    status: Match.status,
    elapsed_seconds: null,
    pid: null,
    thief_id: Match.thief_agent_id,
    detective_id: Match.detective_agent_id,
    scenario: Match.scenario
}).
