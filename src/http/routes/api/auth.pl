:- module(api_auth, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../controller/auth_orchestrator').

:- http_handler(root(api/v1/auth/signup), signup_handler, [methods([post, options])]).
:- http_handler(root(api/v1/auth/login), login_handler, [methods([post, options])]).
:- http_handler(root(api/v1/auth/verify), verify_handler, [methods([get, options])]).

%!  signup_handler(+Request) is det.
%
%   Encaminha requisições de cadastro de usuário.
signup_handler(Request) :-
    cors_enable(Request, [methods([post, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    (   Method == options
    ->  format("Content-type: text/plain~n~n")
    ;   Method == post
    ->  signup_post(Request)
    ;   reply_json_dict(_{error: "method_not_allowed"}, [status(405)])
    ).

%!  signup_post(+Request) is det.
%
%   Processa cadastro com payload JSON e devolve resposta HTTP.
signup_post(Request) :-
    auth_orchestrator:signup_from_request(Request, Status, Payload),
    reply_json_dict(Payload, [status(Status)]).

%!  login_handler(+Request) is det.
%
%   Encaminha requisições de login.
login_handler(Request) :-
    cors_enable(Request, [methods([post, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    (   Method == options
    ->  format("Content-type: text/plain~n~n")
    ;   Method == post
    ->  login_post(Request)
    ;   reply_json_dict(_{error: "method_not_allowed"}, [status(405)])
    ).

%!  login_post(+Request) is det.
%
%   Processa login com payload JSON e devolve token de sessão quando válido.
login_post(Request) :-
    auth_orchestrator:login_from_request(Request, Status, Payload),
    reply_json_dict(Payload, [status(Status)]).

%!  verify_handler(+Request) is det.
%
%   Encaminha verificação de email por token.
verify_handler(Request) :-
    cors_enable(Request, [methods([get, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    (   Method == options
    ->  format("Content-type: text/plain~n~n")
    ;   Method == get
    ->  verify_get(Request)
    ;   reply_json_dict(_{error: "method_not_allowed"}, [status(405)])
    ).

%!  verify_get(+Request) is det.
%
%   Processa verificação de email com query-string `token`.
verify_get(Request) :-
    auth_orchestrator:verify_from_request(Request, Status, Payload),
    reply_json_dict(Payload, [status(Status)]).
