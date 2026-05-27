:- module(api_agents_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../../db/sqlite_store').

% Prefix em /api/v1/agents/ para capturar o ID. /api/v1/agents (sem barra) tem
% handler proprio (lista) e ganha pela especificidade.
:- http_handler('/api/v1/agents/', handler,
                [methods([get, options]), prefix]).

% =============================
% Handler
% =============================

handler(Request) :-
    cors_enable(Request, [methods([get, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    memberchk(path(Path), Request),
    dispatch(Method, Path).

dispatch(options, _) :-
    format("Content-type: text/plain~n~n").
dispatch(get, Path) :-
    handle_get(Path).
dispatch(_, _) :-
    reply(405, _{error: "method_not_allowed"}).

handle_get(Path) :-
    extract_id(Path, Id),
    !,
    load_agent(Id, Status, Payload),
    reply(Status, Payload).
handle_get(_) :-
    reply(404, _{error: "not_found"}).

extract_id(Path, Id) :-
    atom_concat('/api/v1/agents/', Id, Path),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_agent(Id, 200, _{agent: Public}) :-
    sqlite_store:get_agent(Id, Agent),
    !,
    strip_source(Agent, Public).
load_agent(_, 404, _{error: "agent_not_found"}).

% Remove `source_text` antes de responder pela API. O codigo do agente eh
% privado; deixar publico permitiria copia trivial.
strip_source(Agent, Public) :- del_dict(source_text, Agent, _, Public), !.
strip_source(Agent, Agent).

% =============================
% Resposta (JSON)
% =============================

reply(Status, Payload) :-
    reply_json_dict(Payload, [status(Status)]).
