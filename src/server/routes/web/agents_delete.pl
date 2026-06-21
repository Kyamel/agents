:- module(route_agents_delete, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').
:- use_module('../../http/web_session').

% Rota /agents/<id>/delete. O `Id` e uma variavel de segmento (segment_pattern),
% entao convive com /agents/new (GET/POST) e /agents (lista) sem colidir.
:- http_handler(root(agents/Id/delete), handler(Id), [methods([post, delete])]).

% =============================
% Handler
% =============================

handler(Id, Request) :-
    web_session:require_user(Request, User),
    process_delete(User, Id).

% =============================
% Logica (autorizacao + DB)
% =============================

process_delete(User, Id) :-
    db:get_agent(Id, Agent),
    !,
    ensure_owner(User, Agent),
    db:delete_agent(Id),
    engine:forget_agent(Id),
    reply_empty.
process_delete(_, _) :-
    reply_not_found.

ensure_owner(User, Agent) :-
    normalize_id(User.id, UserIdN),
    normalize_id(Agent.owner_user_id, OwnerIdN),
    same_owner(UserIdN, OwnerIdN).

same_owner(Id, Id) :- !.
same_owner(_, _) :-
    throw(http_reply(forbidden('/agents'),
                     [],
                     [content_type('text/plain'),
                      status(403)])).

normalize_id(X, S) :- atom(X), !, atom_string(X, S).
normalize_id(X, X) :- string(X), !.
normalize_id(X, S) :- term_string(X, S).

% =============================
% Resposta
% =============================

% 200 OK com corpo vazio; o htmx faz o swap do cartao por nada.
reply_empty :-
    format("Status: 200 OK~n"),
    format("Content-Type: text/html; charset=UTF-8~n~n").

reply_not_found :-
    format("Status: 404 Not Found~n"),
    format("Content-Type: text/plain; charset=UTF-8~n~n"),
    format("Agente nao encontrado.~n").
