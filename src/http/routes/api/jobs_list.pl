:- module(api_jobs_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../engine/engine').

% Lista os jobs de partida ATIVOS (na fila + executando), com tempo decorrido.
% Partidas ja concluidas/falhas saem deste registro em memoria; o estado final
% delas vive em `matches` (GET /api/v1/matches/<id>).
:- http_handler('/api/v1/jobs', handler, [methods([get, options])]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, _Request) :-
    engine:job_snapshot(Jobs),
    reply_json(200, _{jobs: Jobs}).
