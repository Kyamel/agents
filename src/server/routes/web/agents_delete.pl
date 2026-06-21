:- module(route_agents_delete, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').
:- use_module('../../http/web_session').

% Prefix em /agents/ para capturar /agents/<id>. Restrito a DELETE para nao
% colidir com os handlers GET/POST de /agents/new.
:- http_handler('/agents/', handler, [method(delete), prefix]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:require_user(Request, User),
    memberchk(path(Path), Request),
    handle_path(Path, User).

handle_path(Path, User) :-
    extract_id(Path, Id),
    !,
    process_delete(User, Id).
handle_path(_, _) :-
    reply_not_found.

% =============================
% Logica (autorizacao + DB)
% =============================

extract_id(Path, Id) :-
    atom_concat('/agents/', Id, Path),
    Id \== '',
    Id \== new.

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
