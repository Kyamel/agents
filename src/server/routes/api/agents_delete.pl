:- module(api_agents_delete, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../http/api_endpoint').
:- use_module('../../http/authz').
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').

% Rota de exclusao: /api/v1/agents/<id>/delete. O `Id` e uma variavel de
% segmento (segment_pattern do http_dispatch), entao essa rota convive com o
% prefixo /api/v1/agents/ do agents_show sem colidir: o dispatcher casa o padrao
% <id>/delete antes de cair no handler de prefixo.
:- http_handler(root(api/v1/agents/Id/delete), handler(Id),
                [methods([post, delete, options])]).

handler(Id, Request) :-
    api_handle(Request, [post, delete, options], dispatch(Id)).

% So o dono exclui; exige bearer token valido.
dispatch(Id, _Method, Request) :-
    authz:require_bearer_token(Request, UserId),
    process_delete(UserId, Id, Status, Payload),
    reply_json(Status, Payload).

% =============================
% Logica (autorizacao + DB)
% =============================

% Agente ja excluido (soft delete) e tratado como inexistente.
process_delete(UserId, Id, Status, Payload) :-
    db:get_agent(Id, Agent),
    active_agent(Agent),
    !,
    delete_owned(UserId, Id, Agent, Status, Payload).
process_delete(_, _, 404, _{error: "agent_not_found"}).

active_agent(Agent) :-
    get_dict(deleted_at, Agent, DeletedAt),
    DeletedAt == "".

delete_owned(UserId, Id, Agent, 200, _{status: "deleted", id: Id}) :-
    same_owner(UserId, Agent.owner_user_id),
    !,
    db:delete_agent(Id),
    engine:forget_agent(Id).
delete_owned(_, _, _, 403, _{error: "forbidden"}).

same_owner(A, B) :-
    normalize_id(A, N),
    normalize_id(B, N).

normalize_id(X, S) :- atom(X), !, atom_string(X, S).
normalize_id(X, X) :- string(X), !.
normalize_id(X, S) :- term_string(X, S).
