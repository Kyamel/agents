:- module(agent_registry, [
    register_agent_source/5,
    register_agent_source/6,
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
    register_agent_source(UserId, Name, Role, SourceText, false, Agent).

%!  register_agent_source(+UserId, +Name, +Role, +SourceText, +IsPrivate, -Agent) is det.
%
%   Versao completa usada pela UI/API para controlar exposicao do codigo.
register_agent_source(UserId, Name, Role, SourceText, IsPrivate, Agent) :-
    valid_user_id(UserId),
    must_be(string, Name),
    must_be(string, Role),
    must_be(string, SourceText),
    must_be(boolean, IsPrivate),

    validate_role(Role),
    sandbox:validate_agent_source(SourceText),

    config:agent_max_source_bytes(MaxBytes),
    string_length(SourceText, Len),
    Len =< MaxBytes,

    db:save_agent(UserId, Name, Role, SourceText, IsPrivate, AgentId),
    db:get_agent(AgentId, AgentWithSource),
    del_dict(source_text, AgentWithSource, _, Agent).

validate_role("thief").
validate_role("detective").
validate_role(Role) :-
    domain_error(role, Role).

valid_user_id(UserId) :-
    ( integer(UserId) ; string(UserId) ),
    !.
valid_user_id(UserId) :-
    type_error(user_id, UserId).

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
