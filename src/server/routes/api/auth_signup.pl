:- module(api_auth_signup, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../http/json_request').
:- use_module('../../../services/accounts').

path(root(api/v1/auth/signup), []).
accept(post, none).

handle(post, Request, _User, _Params, Outcome) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, username, Username),
    json_request:require_string(Body, email, Email),
    json_request:require_string(Body, password, Password),
    accounts:signup(Username, Email, Password, Result),
    signup_outcome(Username, Result, Outcome).

signup_outcome(_Username, email_exists, email_exists).
signup_outcome(Username, created(UserId, MailStatus0),
               created(Username, UserId, MailStatus)) :-
    mail_status_string(MailStatus0, MailStatus).

render(_Request, email_exists, json(409, _{error: "email_already_exists"})).
render(_Request, created(Username, UserId, MailStatus),
       json(201, _{
           status: "created",
           user_id: UserId,
           username: Username,
           email_delivery: MailStatus,
           message: "check your inbox to verify your email"
       })).

mail_status_string(sent, "sent").
mail_status_string(console, "console").
mail_status_string(failed, "failed").

:- api_endpoint:mount(api_auth_signup).
