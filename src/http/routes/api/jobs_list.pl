:- module(api_jobs_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../../engine/match_queue').

% Lista os jobs de partida ATIVOS (na fila + executando), com tempo decorrido.
% Partidas ja concluidas/falhas saem deste registro em memoria; o estado final
% delas vive em `matches` (GET /api/v1/matches/<id>).
:- http_handler('/api/v1/jobs', handler, [methods([get, options])]).

handler(Request) :-
    cors_enable(Request, [methods([get, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    dispatch(Method).

dispatch(options) :-
    format("Content-type: text/plain~n~n").
dispatch(get) :-
    match_queue:job_snapshot(Jobs),
    reply_json_dict(_{jobs: Jobs}, [status(200)]).
dispatch(_) :-
    reply_json_dict(_{error: "method_not_allowed"}, [status(405)]).
