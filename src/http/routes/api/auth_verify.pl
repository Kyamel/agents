:- module(api_auth_verify, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../auth_orchestrator').

:- http_handler(root(api/v1/auth/verify), handler, [methods([get, options])]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, Request) :-
    auth_orchestrator:verify_from_request(Request, Status, Payload),
    reply_json(Status, Payload).
