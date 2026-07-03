:- module(sandbox, [
    validate_agent_source/1
]).

:- use_module(library(dcg/basics)).

% Validação mínima: rejeita padrões perigosos no código enviado por agentes.
% NÃO substitui isolamento em processo separado.
validate_agent_source(SourceText) :-
    must_be(string, SourceText),
    blocked_pattern("initialization(", SourceText),
    blocked_pattern(":- use_module", SourceText),
    blocked_pattern("open(", SourceText),
    blocked_pattern("process_create(", SourceText),
    blocked_pattern("shell(", SourceText),
    blocked_pattern("consult(", SourceText).

blocked_pattern(Pattern, SourceText) :-
    sub_string(SourceText, _, _, _, Pattern),
    !,
    throw(error(permission_error(load, agent_source, Pattern), _)). 
blocked_pattern(_Pattern, _SourceText).
