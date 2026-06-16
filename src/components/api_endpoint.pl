:- module(api_endpoint, [
    api_handle/3,
    reply_json/2
]).

:- use_module(library(http/http_json), [reply_json_dict/2]).
:- use_module(library(http/http_cors)).
:- use_module('../http/security/rate_limit').

% Boilerplate comum a todas as rotas JSON da API: habilita CORS, aplica o rate
% limit por IP, extrai o metodo e despacha. Responde OPTIONS (preflight) e
% metodos nao suportados (405) automaticamente, para que cada rota so precise
% tratar os metodos que de fato implementa.
%
% Uso numa rota:
%
%   handler(Request) :- api_endpoint:api_handle(Request, [get, post, options], dispatch).
%   dispatch(get,  _Request) :- ..., reply_json(200, _{...}).
%   dispatch(post, Request)  :- ..., reply_json(201, _{...}).
%
% `dispatch/2` so precisa ter clausulas para os metodos reais; se nenhuma casar,
% api_handle responde 405.

:- meta_predicate api_handle(+, +, 2).

%!  api_handle(+Request, +Methods, :Dispatch) is det.
api_handle(Request, Methods, Dispatch) :-
    cors_enable(Request, [methods(Methods)]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    route_method(Method, Request, Dispatch).

:- meta_predicate route_method(+, +, 2).

route_method(options, _Request, _Dispatch) :-
    !,
    format("Content-type: text/plain~n~n").
route_method(Method, Request, Dispatch) :-
    call(Dispatch, Method, Request),
    !.
route_method(_Method, _Request, _Dispatch) :-
    reply_json(405, _{error: "method_not_allowed"}).

%!  reply_json(+Status, +Payload) is det.
%
%   Responde `Payload` (dict) como JSON com o codigo HTTP `Status`.
reply_json(Status, Payload) :-
    reply_json_dict(Payload, [status(Status)]).
