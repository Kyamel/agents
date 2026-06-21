:- module(endpoint, [
    mount/1
]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json), [reply_json_dict/2]).
:- use_module(library(http/http_cors)).
:- use_module('../http/authz').
:- use_module('../http/rate_limit').
:- use_module('../http/web_session').
:- use_module('../../db/db').

% Mini-framework de endpoints (estilo "behaviour").
%
% Um endpoint e um modulo que define o CONTRATO abaixo; o `mount/1` generico
% transforma isso em rota HTTP, cuidando de CORS, rate limit, auth, OPTIONS e
% erros. O autor do endpoint nunca toca nesse boilerplate.


%!  mount(+Module) is det.
%
%   Registra a rota do endpoint. Chame uma vez, ao final do modulo:
%       :- endpoint:mount(meu_modulo).
mount(Module) :-
    Module:endpoint_methods(Methods),
    Module:endpoint_path(PathTerm, Params),
    http_handler(PathTerm, endpoint:run(Module, Methods, Params),
                 [methods(Methods)]).

% Closure de execucao: o http_dispatch chama com o Request no fim. Quando o path
% tem variaveis de segmento, os vars em Params chegam aqui ja ligados.
run(Module, Methods, Params, Request) :-
    Module:style(Style),
    catch(serve(Module, Methods, Params, Request, Style),
          Caught,
          handle_caught(Caught, Style)).

serve(Module, Methods, Params, Request, Style) :-
    cross_cutting(Style, Methods, Request, Flow),
    continue(Flow, Module, Params, Request).

% `done` = OPTIONS ja respondido pelo cross-cutting; `proceed` = segue o fluxo.
continue(done, _Module, _Params, _Request).
continue(proceed, Module, Params, Request) :-
    Module:endpoint_auth(Kind),
    require_auth(Kind, Request, Auth),
    params_dict(Params, ParamsDict),
    Module:handle(Request, Auth, ParamsDict, Outcome),
    Module:render(Outcome, Reply),
    send(Reply).

% =============================================================================
% Cross-cutting por estilo
% =============================================================================

% JSON: habilita CORS, aplica rate limit por IP e responde preflight OPTIONS.
cross_cutting(json, Methods, Request, Flow) :-
    cors_enable(Request, [methods(Methods)]),
    rate_limit:enforce_ip_rate_limit(Request),
    json_flow(Request, Flow).
cross_cutting(web, _Methods, _Request, proceed).

% OPTIONS (preflight CORS) ja foi tratado: responde e para. Senao, segue.
json_flow(Request, done) :-
    memberchk(method(options), Request),
    !,
    format("Content-type: text/plain~n~n").
json_flow(_Request, proceed).

% =============================================================================
% Autenticacao plugavel (resolve bearer vs cookie no mesmo lugar)
% =============================================================================

require_auth(none, _Request, anon).
require_auth(bearer, Request, User) :-
    authz:require_bearer_token(Request, UserId),
    db:find_user_by_id(UserId, User).
require_auth(session, Request, User) :-
    web_session:require_user(Request, User).
require_auth(any, Request, User) :-
    auth_kind_for(Request, Kind),
    require_auth(Kind, Request, User).

% Header Authorization presente => bearer; senao, cai pra sessao por cookie.
auth_kind_for(Request, bearer) :-
    memberchk(authorization(_), Request),
    !.
auth_kind_for(_Request, session).

% Params: lista Nome-Var (ja ligada pelo dispatch) -> dict
params_dict(Pairs, Dict) :-
    maplist(pair_to_dict_pair, Pairs, DictPairs),
    dict_pairs(Dict, params, DictPairs).

pair_to_dict_pair(Name-Value, Name-Value).

% =============================================================================
% Emissao de respostas (um lugar so para todos os estilos)
% =============================================================================

send(json(Status, Dict)) :-
    reply_json_dict(Dict, [status(Status)]).
send(empty(Status)) :-
    status_line(Status, Line),
    format("Status: ~w~n", [Line]),
    format("Content-Type: text/html; charset=UTF-8~n~n").
send(text(Status, Text)) :-
    status_line(Status, Line),
    format("Status: ~w~n", [Line]),
    format("Content-Type: text/plain; charset=UTF-8~n~n"),
    format("~w~n", [Text]).
send(redirect(Location)) :-
    format("Status: 303 See Other~n"),
    format("Location: ~w~n", [Location]),
    format("Content-Type: text/html; charset=UTF-8~n~n").

status_line(200, '200 OK').
status_line(201, '201 Created').
status_line(400, '400 Bad Request').
status_line(403, '403 Forbidden').
status_line(404, '404 Not Found').
status_line(422, '422 Unprocessable Entity').
status_line(500, '500 Internal Server Error').
status_line(Code, Code).

% =============================================================================
% Erros: http_reply do framework (401, redirect, etc.) sobe; o resto vira 500.
% =============================================================================

handle_caught(http_reply(Reply), _Style) :-
    !,
    throw(http_reply(Reply)).
handle_caught(http_reply(Reply, Extra, Ctx), _Style) :-
    !,
    throw(http_reply(Reply, Extra, Ctx)).
handle_caught(Error, json) :-
    !,
    print_message(error, Error),
    send(json(500, _{error: "internal_error"})).
handle_caught(Error, web) :-
    print_message(error, Error),
    send(text(500, "Erro interno.")).
