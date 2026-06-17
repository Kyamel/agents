:- module(agent_registry, [
    register_agent_source/5,
    valid_agent_name/1
]).

:- use_module(library(error)).
:- use_module('../config').
:- use_module('../db/db').
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

    config:agent_max_source_bytes(MaxBytes),
    string_length(SourceText, Len),
    Len =< MaxBytes,

    db:save_agent(UserId, Name, Role, SourceText, AgentId),
    Agent = _{
        id: AgentId,
        owner_user_id: UserId,
        name: Name,
        role: Role
    }.

validate_role("thief").
validate_role("detective").
validate_role(Role) :-
    domain_error(role, Role).

%!  valid_agent_name(+Name) is semidet.
%
%   Nome de agente deve ser um slug ASCII: minusculas, digitos e hifens, com ao
%   menos um caractere alfanumerico. Centralizado aqui para as rotas web e API
%   validarem com a mesma regra.
valid_agent_name(Name) :-
    string_length(Name, Len),
    Len =< 60,
    string_codes(Name, Codes),
    forall(member(C, Codes), slug_code(C)),
    once((member(A, Codes), alnum_code(A))).

slug_code(0'-) :- !.
slug_code(C) :- alnum_code(C).

alnum_code(C) :- C >= 0'a, C =< 0'z, !.
alnum_code(C) :- C >= 0'0, C =< 0'9.
