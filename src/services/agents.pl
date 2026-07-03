:- module(agents, [
    delete_agent/3,
    list_page/4,
    list_page_with_owners/4,
    public_view/2
]).

:- use_module('../db/db').
:- use_module('../engine/engine').
:- use_module('./scopes').
:- use_module('./users').
:- use_module(library(apply)).

% Camada de servico do recurso "agente". Contem a regra de negocio e NUNCA
% escreve resposta HTTP: devolve um Outcome (termo de dados) que cada rota
% (web/api) traduz para o seu formato.

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

%!  list_page(+Page, +PerPage, -Agents, -Pagination) is det.
%   Uma pagina de agentes (leitura direta, sem enriquecimento).
list_page(Page, PerPage, Agents, Pagination) :-
    db:list_agents_page(Page, PerPage, Agents, Pagination).

%!  public_view(+Id, -Outcome) is det.
%
%   Visao publica de um agente. Outcome: agent(Public) | not_found. Agentes
%   publicos expõem o codigo como `source`; privados mantem apenas metadados.
%   `source_text` e detalhe interno do banco e nunca sai daqui.
public_view(Id, agent(Public)) :-
    db:get_agent(Id, Agent),
    !,
    public_agent(Agent, Public).
public_view(_Id, not_found).

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

%!  list_page_with_owners(+Page, +PerPage, -Agents, -Pagination) is det.
%
%   Uma pagina de agentes, cada um enriquecido com `owner_name` e `stats`.
%   N+1 consciente: volumes pequenos no projeto.
list_page_with_owners(Page, PerPage, AgentsRich, Pagination) :-
    db:list_agents_page(Page, PerPage, Agents, Pagination),
    maplist(with_owner_and_stats, Agents, AgentsRich).

with_owner_and_stats(Agent, Rich) :-
    owner_name(Agent, OwnerName),
    db:agent_record(Agent.id, Stats),
    put_dict(_{owner_name: OwnerName, stats: Stats}, Agent, Rich).

owner_name(Agent, Name) :-
    db:find_user_by_id(Agent.owner_user_id, Owner),
    !,
    users:display_name(Owner, Name).
owner_name(_Agent, "").

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
