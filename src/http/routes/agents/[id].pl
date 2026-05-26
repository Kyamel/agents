:- module(route_agents_resource, [
    handle/2
]).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../db/sqlite_store').
:- use_module('../../../engine/agent_cache').
:- use_module('../../security/web_session').

%!  handle(+Request, +AgentId) is det.
%
%   Endpoint htmx-friendly para DELETE /agents/<id>. Apaga o agente do DB
%   e invalida o cache em disco. So o dono pode excluir.
handle(Request, AgentId) :-
    web_session:require_user(Request, User),
    (   sqlite_store:get_agent(AgentId, Agent)
    ->  ensure_owner(User, Agent),
        sqlite_store:delete_agent(AgentId),
        agent_cache:forget_agent(AgentId),
        reply_empty
    ;   reply_not_found
    ).

ensure_owner(User, Agent) :-
    normalize_id(User.id, UserIdN),
    normalize_id(Agent.owner_user_id, OwnerIdN),
    (   UserIdN == OwnerIdN
    ->  true
    ;   throw(http_reply(forbidden('/agents'),
                         [],
                         [content_type('text/plain'),
                          status(403)]))
    ).

normalize_id(X, S) :- atom(X), !, atom_string(X, S).
normalize_id(X, X) :- string(X), !.
normalize_id(X, S) :- term_string(X, S).

%!  reply_empty is det.
%
%   200 OK com corpo vazio; o htmx faz o swap do cartao por nada.
reply_empty :-
    format("Status: 200 OK~n"),
    format("Content-Type: text/html; charset=UTF-8~n~n").

reply_not_found :-
    format("Status: 404 Not Found~n"),
    format("Content-Type: text/plain; charset=UTF-8~n~n"),
    format("Agente nao encontrado.~n").
