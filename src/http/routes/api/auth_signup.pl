:- module(api_auth_signup, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../controller/auth_orchestrator').

:- http_handler(root(api/v1/auth/signup), handler, [methods([post, options])]).

% =============================
% Handler
% =============================

handler(Request) :-
    cors_enable(Request, [methods([post, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    dispatch(Method, Request).

dispatch(options, _) :-
    format("Content-type: text/plain~n~n").
dispatch(post, Request) :-
    process(Request, Status, Payload),
    reply(Status, Payload).
dispatch(_, _) :-
    reply(405, _{error: "method_not_allowed"}).

% =============================
% Logica
% =============================

process(Request, Status, Payload) :-
    auth_orchestrator:signup_from_request(Request, Status, Payload).

% =============================
% Resposta (JSON)
% =============================

reply(Status, Payload) :-
    reply_json_dict(Payload, [status(Status)]).
