:- module(api_agents, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../security/authz').
:- use_module('../../controller/agents_orchestrator').
:- use_module('../../../db/sqlite_store', [get_agent/2]).

:- http_handler(root(api/v1/agents), agents_handler,
                [prefix, methods([get, post, options])]).

%!  agents_handler(+Request) is det.
%
%   Ponto de entrada da API de agentes; despacha colecao e recurso individual.
agents_handler(Request) :-
    cors_enable(Request, [methods([get, post, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    memberchk(path(Path), Request),
    agents_route(Path, Method, Request).

%!  agents_route(+Path, +Method, +Request) is det.
%
%   Separa `/api/v1/agents` (colecao) de `/api/v1/agents/<id>` (recurso).
agents_route('/api/v1/agents', Method, Request) :-
    !,
    agents_collection(Method, Request).
agents_route(Path, Method, Request) :-
    atom_concat('/api/v1/agents/', Id, Path),
    Id \== '',
    !,
    agent_resource(Id, Method, Request).
agents_route(_, _, _) :-
    reply_json_dict(_{error: "not_found"}, [status(404)]).

%!  agents_collection(+Method, +Request) is det.
%
%   Operacoes de listagem e criacao de agentes.
agents_collection(options, _) :-
    format("Content-type: text/plain~n~n").
agents_collection(get, _Request) :-
    agents_orchestrator:list_agents(Agents),
    reply_json_dict(_{agents: Agents}).
agents_collection(post, Request) :-
    authz:require_bearer_token(Request, UserId),
    agents_orchestrator:create_agent_from_request(UserId, Request, Status, Payload),
    reply_json_dict(Payload, [status(Status)]).
agents_collection(_, _) :-
    reply_json_dict(_{error: "method_not_allowed"}, [status(405)]).

%!  agent_resource(+Id, +Method, +Request) is det.
%
%   Operacoes sobre um agente especifico.
agent_resource(_, options, _) :-
    !,
    format("Content-type: text/plain~n~n").
agent_resource(Id, get, _Request) :-
    !,
    (   sqlite_store:get_agent(Id, Agent)
    ->  strip_source(Agent, Public),
        reply_json_dict(_{agent: Public})
    ;   reply_json_dict(_{error: "agent_not_found"}, [status(404)])
    ).
agent_resource(_, _, _) :-
    reply_json_dict(_{error: "method_not_allowed"}, [status(405)]).

%!  strip_source(+Agent, -Public) is det.
%
%   Remove `source_text` antes de responder pela API. O codigo do agente
%   eh privado; deixar publico permitiria copia trivial.
strip_source(Agent, Public) :-
    (   del_dict(source_text, Agent, _, Public)
    ->  true
    ;   Public = Agent
    ).
