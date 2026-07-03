:- module(api_endpoint, [
    mount/1
]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json), [reply_json_dict/2]).
:- use_module(library(http/http_cors)).
:- use_module(authz).
:- use_module(rate_limit).
:- use_module('../../db/db').

% Recipe declarativo dos endpoints JSON da API (rotas em routes/api/).
%
% Um endpoint e um modulo que preenche o CONTRATO abaixo; `mount/1` transforma
% isso numa rota HTTP, cuidando de CORS, rate limit por IP, auth por metodo,
% preflight OPTIONS e erros. So trata JSON: paginas HTML (routes/web/) usam
% http_handler direto + page:reply_page.
%
% Contrato do modulo:
%   path(-PathTerm, -Params)                        rota e parametros de segmento
%   accept(-Method, -Auth)                          auth por metodo: none | bearer
%   handle(+Method, +Request, +User, +Params, -Outcome)
%   render(+Request, +Outcome, -Reply)              Reply: json(Status, Dict)
%
% `Params` e uma lista Nome-Var; as vars sao ligadas pelo dispatch a partir dos
% segmentos do path e chegam ao handle como um dict.

%!  mount(+Module) is det.
%
%   Registra a rota do endpoint. Chame uma vez, ao final do modulo:
%       :- api_endpoint:mount(meu_modulo).
mount(Module) :-
    methods(Module, Methods),
    Module:path(PathTerm, Params),
    http_handler(PathTerm, api_endpoint:run(Module, Params), [methods(Methods)]).

% Metodos aceitos = os de accept/2 + options (preflight CORS).
methods(Module, [options|Accepted]) :-
    findall(M, Module:accept(M, _Auth), Accepted).

% Closure de execucao: o http_dispatch chama com o Request no fim. Quando o path
% tem variaveis de segmento, as vars em Params chegam aqui ja ligadas.
run(Module, Params, Request) :-
    catch(serve(Module, Params, Request),
          Caught,
          handle_caught(Caught)).

serve(Module, Params, Request) :-
    memberchk(method(Method), Request),
    findall(M, Module:accept(M, _), Ms),
    cors_enable(Request, [methods([options|Ms])]),
    rate_limit:enforce_ip_rate_limit(Request),
    continue(Method, Module, Params, Request).

% OPTIONS (preflight CORS): responde e para. Senao, segue o fluxo normal.
continue(options, _Module, _Params, _Request) :-
    !,
    format("Content-type: text/plain~n~n").
continue(Method, Module, Params, Request) :-
    Module:accept(Method, Auth),
    require_auth(Auth, Request, User),
    params_dict(Params, ParamsDict),
    Module:handle(Method, Request, User, ParamsDict, Outcome),
    Module:render(Request, Outcome, Reply),
    send(Reply).

% Autenticacao plugavel por metodo.

require_auth(none, _Request, anon).
require_auth(bearer, Request, User) :-
    authz:require_bearer_token(Request, UserId),
    db:find_user_by_id(UserId, User).

% Params: lista Nome-Var (ja ligada pelo dispatch) -> dict.

params_dict(Pairs, Dict) :-
    maplist(pair_to_dict_pair, Pairs, DictPairs),
    dict_pairs(Dict, params, DictPairs).

pair_to_dict_pair(Name-Value, Name-Value).

% Emissao de respostas.

send(json(Status, Dict)) :-
    reply_json_dict(Dict, [status(Status)]).

% Erros: http_reply do framework (401, bad_request, 429, ...) sobe; o resto vira
% 500 logado.

handle_caught(http_reply(Reply)) :-
    !,
    throw(http_reply(Reply)).
handle_caught(http_reply(Reply, Extra, Ctx)) :-
    !,
    throw(http_reply(Reply, Extra, Ctx)).
handle_caught(Error) :-
    print_message(error, Error),
    send(json(500, _{error: "internal_error"})).
