:- module(api_agents_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../db/db').

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
    db:get_agent(Id, Agent),
    !,
    public_agent(Agent, Public).
load_agent(_, 404, _{error: "agent_not_found"}).

% Agentes publicos expõem o codigo como `source`; privados mantem apenas
% metadados. `source_text` continua sendo detalhe interno do banco.
public_agent(Agent, Public) :-
    get_dict(source_text, Agent, Source),
    del_dict(source_text, Agent, _, WithoutSourceText),
    Agent.is_private == false,
    !,
    Public = WithoutSourceText.put(source, Source).
public_agent(Agent, Public) :-
    del_dict(source_text, Agent, _, Public),
    !.
public_agent(Agent, Agent).
