:- module(route_logout, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../http/web_session').

:- http_handler(root(logout), handler, [method(post)]).

handler(Request) :-
    web_session:revoke_web_session(Request),
    reply.

reply :-
    web_session:send_logout_redirect('/login?notice=logged_out').
