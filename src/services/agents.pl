:- module(agents, [
    delete_agent/3,
    list_page/4,
    list_page_with_owners/4,
    profile_page/4,
    performance_stats/2,
    source_view/2
]).

:- use_module('../db/db').
:- use_module('../engine/engine').
:- use_module('./scopes').
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

%!  profile_page(+Id, +Page, +PerPage, -Outcome) is det.
%
%   Perfil público compartilhado pela página HTML e pela API. O histórico vem
%   paginado e cada partida recebe o papel, resultado e adversário do agente.
%   Outcome:
%     profile(Agent, Owner, Stats, Matches, Pagination) | not_found.
profile_page(Id, Page, PerPage,
             profile(Public, Owner, Stats, History, Pagination)) :-
    db:get_agent(Id, Agent),
    !,
    public_agent(Agent, Public),
    public_owner(Agent.owner_user_id, Owner),
    db:agent_record(Agent.id, Record),
    performance_stats(Record, Stats),
    db:list_matches_by_agent_page(
        Agent.id,
        Page,
        PerPage,
        Matches,
        Pagination
    ),
    maplist(agent_match(Agent.id), Matches, History).
profile_page(_, _, _, not_found).

%!  source_view(+Id, -Outcome) is det.
%
%   Código-fonte público para a página dedicada. Agentes privados existem, mas
%   seu source nunca deixa a camada de serviço.
source_view(Id, source(Public, Source)) :-
    db:get_agent(Id, Agent),
    Agent.is_private == false,
    !,
    get_dict(source_text, Agent, Source),
    del_dict(source_text, Agent, _, Public).
source_view(Id, private) :-
    db:get_agent(Id, _),
    !.
source_view(_Id, not_found).

%!  performance_stats(+Record, -Stats) is det.
%
%   Acrescenta total de partidas concluídas e win rate percentual ao
%   retrospecto básico já usado no restante do sistema.
performance_stats(Record, Stats) :-
    Total is Record.wins + Record.losses + Record.draws,
    win_rate(Record.wins, Total, WinRate),
    Stats = Record.put(_{
        total: Total,
        win_rate: WinRate
    }).

win_rate(_Wins, 0, 0.0) :- !.
win_rate(Wins, Total, Rate) :-
    Rounded is round(Wins * 1000 / Total),
    Rate is float(Rounded) / 10.0.

public_owner(OwnerId, Public) :-
    db:find_user_by_id(OwnerId, Owner),
    !,
    Public = _{id: Owner.id, username: Owner.username}.
public_owner(OwnerId, Public) :-
    Public = _{id: OwnerId, username: ""}.

agent_match(AgentId, Match, Rich) :-
    agent_side(Match, AgentId, Side, OpponentId, OpponentName),
    agent_result(Match.status, Match.winner, Side, Result),
    Rich = Match.put(_{
        agent_side: Side,
        agent_result: Result,
        opponent_id: OpponentId,
        opponent_name: OpponentName
    }).

agent_side(Match, AgentId, "thief", OpponentId, OpponentName) :-
    Match.thief_agent_id =:= AgentId,
    !,
    OpponentId = Match.detective_agent_id,
    OpponentName = Match.detective_agent_name.
agent_side(Match, _AgentId, "detective", OpponentId, OpponentName) :-
    OpponentId = Match.thief_agent_id,
    OpponentName = Match.thief_agent_name.

agent_result("done", "draw", _Side, "draw") :- !.
agent_result("done", Winner, Side, "win") :-
    Winner == Side,
    !.
agent_result("done", _Winner, _Side, "loss") :- !.
agent_result("queued", _Winner, _Side, "pending") :- !.
agent_result("running", _Winner, _Side, "pending") :- !.
agent_result(_Status, _Winner, _Side, "not_completed").

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
    Name = Owner.username.
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
