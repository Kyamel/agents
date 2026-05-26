:- module(server, [
    start/0
]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_cors)).
:- use_module('../config/env').
:- use_module('./routes/static').
:- use_module('./routes/index').
:- use_module('./routes/agents').
:- use_module('./routes/matches').
:- use_module('./routes/users').
:- use_module('./routes/auth_pages').
:- use_module('./routes/api/health').
:- use_module('./routes/api/auth').
:- use_module('./routes/api/agents').
:- use_module('./routes/api/matches').


:- set_setting(http:cors, []).
:- http_handler(root(api), options_handler, [method(options), prefix]).

%!  start is det.
%
%   Inicia o servidor HTTP. TLS eh terminado no reverse proxy (Caddy/nginx);
%   esse processo so fala HTTP. Atras do proxy, defina TRUST_PROXY=true para
%   o rate limiter honrar os headers X-Forwarded-*.
start :-
    env:env_int('HTTP_PORT', 8080, HttpPort),
    http_server(http_dispatch, [port(HttpPort)]),
    format('HTTP listening on :~w~n', [HttpPort]).

%!  options_handler(+Request) is det.
%
%   Responde preflight CORS para qualquer rota registrada.
options_handler(Request) :-
    cors_enable(Request, [methods([get, post, put, delete, options])]),
    format('~n').
