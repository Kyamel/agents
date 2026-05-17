:- module(server, [
    start/0
]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/http_ssl_plugin)).
:- use_module('../config/env').
:- use_module('./routes/index').
:- use_module('./routes/agents').
:- use_module('./routes/matches').


:- set_setting(http:cors, [*]).
:- http_handler(root(api), options_handler, [method(options), prefix]).

%!  start is det.
%
%   Inicia servidor HTTP e, opcionalmente, HTTPS conforme variáveis de ambiente.
start :-
    env:env_int('HTTP_PORT', 8080, HttpPort),
    http_server(http_dispatch, [port(HttpPort)]),
    format('HTTP listening on :~w~n', [HttpPort]),

    env:env_bool('ENABLE_HTTPS', false, EnableHttps),
    (   EnableHttps == true
    ->  start_https
    ;   true
    ).

%!  start_https is det.
%
%   Inicia listener HTTPS com certificado e chave configurados por ambiente.
start_https :-
    env:env_int('HTTPS_PORT', 8443, HttpsPort),
    env:env_required_string('HTTPS_CERT_FILE', CertFile),
    env:env_required_string('HTTPS_KEY_FILE', KeyFile),
    env:env_string('HTTPS_KEY_PASSWORD', '', Password),
    ssl_options(CertFile, KeyFile, Password, SslOptions),
    http_server(http_dispatch, [port(HttpsPort), ssl(SslOptions)]),
    format('HTTPS listening on :~w~n', [HttpsPort]).

%!  ssl_options(+CertFile, +KeyFile, +Password, -Options) is det.
%
%   Monta opções SSL para `http_server/2`.
ssl_options(CertFile, KeyFile, "", [
    certificate_file(CertFile),
    key_file(KeyFile)
]).
ssl_options(CertFile, KeyFile, Password, [
    certificate_file(CertFile),
    key_file(KeyFile),
    password(Password)
]).

%!  options_handler(+Request) is det.
%
%   Responde preflight CORS para qualquer rota registrada.
options_handler(Request) :-
    cors_enable(Request, [methods([get, post, put, delete, options])]),
    format('~n').
