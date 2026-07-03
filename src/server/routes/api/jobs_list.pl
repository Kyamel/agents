:- module(api_jobs_list, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../../services/jobs').

% Lista os jobs de partida ATIVOS (na fila + executando), com tempo decorrido.
% Partidas ja concluidas/falhas saem deste registro em memoria; o estado final
% delas vive em `matches` (GET /api/v1/matches/<id>).
path(root(api/v1/jobs), []).
accept(get, none).

handle(get, _Request, _User, _Params, jobs(Jobs)) :-
    jobs:snapshot(Jobs).

render(_Request, jobs(Jobs), json(200, _{jobs: Jobs})).

:- api_endpoint:mount(api_jobs_list).
