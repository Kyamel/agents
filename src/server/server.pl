:- module(server, [
    start/0
]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_cors)).
:- use_module('../config').

% Rotas web
:- use_module('./routes/static').
:- use_module('./routes/index').
:- use_module('./routes/docs').
:- use_module('./routes/signup').
:- use_module('./routes/login').
:- use_module('./routes/logout').
:- use_module('./routes/auth_verify').
:- use_module('./routes/agents_list').
:- use_module('./routes/agents_new').
:- use_module('./routes/agents_delete').
:- use_module('./routes/matches_list').
:- use_module('./routes/matches_new').
:- use_module('./routes/matches_show').
:- use_module('./routes/matches_map').
:- use_module('./routes/users_show').

% Rotas API
:- use_module('./routes/api/health').
:- use_module('./routes/api/auth_signup').
:- use_module('./routes/api/auth_login').
:- use_module('./routes/api/auth_verify').
:- use_module('./routes/api/agents_list').
:- use_module('./routes/api/agents_show').
:- use_module('./routes/api/matches_list').
:- use_module('./routes/api/matches_show').
:- use_module('./routes/api/users_show').
:- use_module('./routes/api/jobs_list').
:- use_module('./routes/api/jobs_show').


:- set_setting(http:cors, []).
:- http_handler(root(api), options_handler, [method(options), prefix]).

%!  start is det.
%
%   Inicia o servidor HTTP. TLS eh terminado no reverse proxy (Caddy/nginx);
%   esse processo so fala HTTP. Atras do proxy, ligue `trust_proxy(true)` em
%   `src/config.pl` para o rate limiter honrar os headers X-Forwarded-*.
start :-
    config:http_port(HttpPort),
    http_server(http_dispatch, [port(HttpPort)]).

% Responde preflight CORS para qualquer rota registrada.
options_handler(Request) :-
    cors_enable(Request, [methods([get, post, put, delete, options])]),
    format('~n').
