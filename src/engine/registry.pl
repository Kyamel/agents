:- module(agent_registry, [
    register_agent_source/5,
    register_agent_source/6,
    register_agent_source_from_module/4,
    register_agent_source_from_module/5,
    valid_agent_name/1
]).

:- use_module(library(error)).
:- use_module('../config').
:- use_module('../db/db').
:- use_module('./sandbox').

register_agent_source_from_module(UserId, Role, SourceText, Agent) :-
    register_agent_source_from_module(UserId, Role, SourceText, false, Agent).

register_agent_source_from_module(UserId, Role, SourceText, IsPrivate, Agent) :-
    agent_name_from_source(SourceText, Name),
    register_agent_source(UserId, Name, Role, SourceText, IsPrivate, Agent).

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
    validate_agent_name(Name),
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

agent_name_from_source(SourceText, Name) :-
    setup_call_cleanup(
        open_string(SourceText, In),
        read_term(In, Term, [syntax_errors(error)]),
        close(In)
    ),
    module_directive(Term, Module),
    atom_string(Module, Name),
    validate_agent_name(Name),
    !.
agent_name_from_source(_SourceText, _Name) :-
    throw(error(domain_error(agent_module_directive, source), _)).

module_directive((:- module(Module, Exports)), Module) :-
    atom(Module),
    is_list(Exports).

validate_agent_name(Name) :-
    valid_agent_name(Name),
    !.
validate_agent_name(Name) :-
    throw(error(domain_error(agent_name, Name), _)).

%!  valid_agent_name(+Name) is semidet.
%
%   Nome de agente vem de `:- module(Name, Exports).`. Aceita atomos Prolog
%   mais expressivos que slug, mas bloqueia nomes vazios, path separators e
%   controles para nao contaminar exibicao ou caminhos de cache.
valid_agent_name(Name) :-
    string_length(Name, Len),
    Len > 0,
    Len =< 60,
    string_codes(Name, Codes),
    forall(member(C, Codes), safe_agent_name_code(C)).

safe_agent_name_code(0'/) :- !, fail.
safe_agent_name_code(0'\\) :- !, fail.
safe_agent_name_code(C) :- C >= 32.
