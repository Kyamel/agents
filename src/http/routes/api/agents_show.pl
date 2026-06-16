:- module(api_agents_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../db/sqlite_store').

% Prefix em /api/v1/agents/ para capturar o ID. /api/v1/agents (sem barra) tem
% handler proprio (lista) e ganha pela especificidade.
:- http_handler('/api/v1/agents/', handler,
                [methods([get, options]), prefix]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, Request) :-
    memberchk(path(Path), Request),
    handle_get(Path).

handle_get(Path) :-
    extract_id(Path, Id),
    !,
    load_agent(Id, Status, Payload),
    reply_json(Status, Payload).
handle_get(_) :-
    reply_json(404, _{error: "not_found"}).

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
