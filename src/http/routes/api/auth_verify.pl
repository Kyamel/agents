:- module(api_auth_verify, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../auth/auth').

:- http_handler(root(api/v1/auth/verify), handler, [methods([get, options])]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, Request) :-
    verify_from_request(Request, Status, Payload),
    reply_json(Status, Payload).

verify_from_request(Request, 200, _{status: "verified", user_id: UserId}) :-
    http_parameters(Request, [token(Token, [string])]),
    auth:verify_email_token(Token, verified(UserId)),
    !.
verify_from_request(_Request, 400, _{error: "invalid_or_expired_token"}).
