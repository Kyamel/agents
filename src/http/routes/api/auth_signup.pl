:- module(api_auth_signup, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../auth_orchestrator').

:- http_handler(root(api/v1/auth/signup), handler, [methods([post, options])]).

handler(Request) :-
    api_handle(Request, [post, options], dispatch).

dispatch(post, Request) :-
    auth_orchestrator:signup_from_request(Request, Status, Payload),
    reply_json(Status, Payload).
