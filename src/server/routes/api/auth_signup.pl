:- module(api_auth_signup, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../http/api_endpoint').
:- use_module('../../../auth/auth').
:- use_module('../../http/json_request').

:- http_handler(root(api/v1/auth/signup), handler, [methods([post, options])]).

handler(Request) :-
    api_handle(Request, [post, options], dispatch).

dispatch(post, Request) :-
    signup_from_request(Request, Status, Payload),
    reply_json(Status, Payload).

signup_from_request(Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, username, Username),
    json_request:require_string(Body, email, Email),
    json_request:require_string(Body, password, Password),
    auth:signup(Username, Email, Password, Outcome),
    signup_payload(Username, Outcome, Status, Payload).

signup_payload(_, email_exists, 409, _{error: "email_already_exists"}).
signup_payload(Username, created(UserId, MailStatus0), 201, Payload) :-
    mail_status_string(MailStatus0, MailStatus),
    Payload = _{
        status: "created",
        user_id: UserId,
        username: Username,
        email_delivery: MailStatus,
        message: "check your inbox to verify your email"
    }.

mail_status_string(sent, "sent").
mail_status_string(console, "console").
mail_status_string(failed, "failed").
