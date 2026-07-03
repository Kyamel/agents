:- module(api_auth_verify, []).

:- use_module(library(http/http_parameters)).
:- use_module('../../http/api_endpoint').
:- use_module('../../../services/accounts').

path(root(api/v1/auth/verify), []).
accept(get, none).

handle(get, Request, _User, _Params, Outcome) :-
    verify(Request, Outcome).

verify(Request, verified(UserId)) :-
    http_parameters(Request, [token(Token, [string])]),
    accounts:verify_email_token(Token, verified(UserId)),
    !.
verify(_Request, invalid).

render(_Request, verified(UserId), json(200, _{status: "verified", user_id: UserId})).
render(_Request, invalid,          json(400, _{error: "invalid_or_expired_token"})).

:- api_endpoint:mount(api_auth_verify).
