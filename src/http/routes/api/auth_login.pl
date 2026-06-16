:- module(api_auth_login, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../auth/account').
:- use_module('../../json_request').

:- http_handler(root(api/v1/auth/login), handler, [methods([post, options])]).

handler(Request) :-
    api_handle(Request, [post, options], dispatch).

dispatch(post, Request) :-
    login_from_request(Request, Status, Payload),
    reply_json(Status, Payload).

login_from_request(Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, email, Email),
    json_request:require_string(Body, password, Password),
    account:login(Email, Password, Outcome),
    login_payload(Outcome, Status, Payload).

login_payload(invalid_credentials, 401, _{error: "invalid_credentials"}).
login_payload(email_not_verified, 403, _{error: "email_not_verified"}).
login_payload(ok(Token, UserId, ExpiresAt), 200, Payload) :-
    Payload = _{
        status: "ok",
        token: Token,
        user_id: UserId,
        expires_at: ExpiresAt
    }.
