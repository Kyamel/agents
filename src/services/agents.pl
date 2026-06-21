:- module(agents_service, [
    delete_agent/3
]).

:- use_module('../db/db').
:- use_module('../engine/engine').
:- use_module('../auth/scopes').

% Camada de servico do recurso "agente". Contem a regra de negocio e NUNCA
% escreve resposta HTTP: devolve um Outcome (termo de dados) que cada rota
% (web/api) traduz para o seu formato. Mesma logica serve aos dois mundos.

%!  delete_agent(+User, +Id, -Outcome) is det.
%
%   Outcome:
%     - deleted(Id) : excluido (soft delete) com sucesso
%     - forbidden   : nao e dono nem tem o scope agent:delete:any
%     - not_found   : inexistente ou ja excluido
delete_agent(User, Id, Outcome) :-
    db:get_agent(Id, Agent),
    active(Agent),
    !,
    delete_active(User, Id, Agent, Outcome).
delete_agent(_User, _Id, not_found).

% Agente existe e esta ativo: decide entre excluir e negar.
delete_active(User, Id, Agent, deleted(Id)) :-
    can_delete(User, Agent),
    !,
    db:delete_agent(Id),
    engine:forget_agent(Id).
delete_active(_User, _Id, _Agent, forbidden).

active(Agent) :-
    get_dict(deleted_at, Agent, DeletedAt),
    DeletedAt == "".

% Dono OU admin (scope agent:delete:any).
can_delete(User, Agent) :-
    is_owner(User, Agent),
    !.
can_delete(User, _Agent) :-
    scopes:has_scope(User, 'agent:delete:any').

is_owner(User, Agent) :-
    is_dict(User),
    normalize_id(User.id, UserIdN),
    normalize_id(Agent.owner_user_id, OwnerIdN),
    UserIdN == OwnerIdN.

normalize_id(X, S) :- atom(X), !, atom_string(X, S).
normalize_id(X, X) :- string(X), !.
normalize_id(X, S) :- term_string(X, S).
