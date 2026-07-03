:- module(api_auth_login, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../http/json_request').
:- use_module('../../../services/accounts').

path(root(api/v1/auth/login), []).
accept(post, none).

handle(post, Request, _User, _Params, Outcome) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, email, Email),
    json_request:require_string(Body, password, Password),
    accounts:login(Email, Password, Outcome).

render(_Request, invalid_credentials, json(401, _{error: "invalid_credentials"})).
render(_Request, email_not_verified,  json(403, _{error: "email_not_verified"})).
render(_Request, ok(Token, UserId, ExpiresAt),
       json(200, _{
           status: "ok",
           token: Token,
           user_id: UserId,
           expires_at: ExpiresAt
       })).

:- api_endpoint:mount(api_auth_login).
