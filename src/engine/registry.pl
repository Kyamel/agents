:- module(agent_registry, [
    register_agent_source/5
]).

:- use_module(library(error)).
:- use_module('../config/env').
:- use_module('../db/sqlite_store').
:- use_module('./sandbox').

%!  register_agent_source(+UserId, +Name, +Role, +SourceText, -Agent) is det.
%
%   Valida e persiste um agente no banco. O DB eh o source-of-truth do
%   codigo: o filesystem em `uploads/agents/<id>.pl` eh um cache
%   read-only materializado pela engine antes de cada partida.
register_agent_source(UserId, Name, Role, SourceText, Agent) :-
    must_be(string, UserId),
    must_be(string, Name),
    must_be(string, Role),
    must_be(string, SourceText),

    validate_role(Role),
    sandbox:validate_agent_source(SourceText),

    env:env_int('AGENT_MAX_SOURCE_BYTES', 65536, MaxBytes),
    string_length(SourceText, Len),
    Len =< MaxBytes,

    sqlite_store:save_agent(UserId, Name, Role, SourceText, AgentId),
    Agent = _{
        id: AgentId,
        owner_user_id: UserId,
        name: Name,
        role: Role
    }.

%!  validate_role(+Role) is det.
%
%   Aceita somente papeis validos de agente.
validate_role("thief").
validate_role("detective").
validate_role(Role) :-
    domain_error(role, Role).
