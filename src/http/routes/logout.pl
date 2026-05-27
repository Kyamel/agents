:- module(route_logout, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../security/web_session').

:- http_handler(root(logout), handler, [method(post)]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:revoke_web_session(Request),
    reply.

% =============================
% Resposta
% =============================

reply :-
    web_session:send_logout_redirect('/login?notice=logged_out').
