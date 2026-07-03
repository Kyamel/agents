:- module(matches, [
    create_match/4,
    agent_has_role/2,
    eligible_rosters/2,
    match_detail/2,
    agent_display_name/2,
    decode_replay/2,
    list_page/4,
    find_match/2
]).

:- use_module('../db/db').
:- use_module('../engine/engine').
:- use_module(library(apply)).
:- use_module(library(http/json)).

% Servico de partidas: valida a escolha de agentes/cenario e enfileira a partida
% (executa em background). Devolve outcome; web/api formatam.

%!  create_match(+ThiefId, +DetectiveId, +Scenario, -Outcome) is det.
%
%   Outcome:
%     - missing_agents
%     - thief_not_found
%     - detective_not_found
%     - invalid_scenario
%     - invalid_roles
%     - created(MatchId)
%     - enqueue_failed
create_match("", _, _, missing_agents) :- !.
create_match(_, "", _, missing_agents) :- !.
create_match(_, _, Scenario, invalid_scenario) :-
    \+ engine:valid_scenario(Scenario),
    !.
create_match(ThiefId, _, _, thief_not_found) :-
    \+ db:get_agent(ThiefId, _),
    !.
create_match(_, DetectiveId, _, detective_not_found) :-
    \+ db:get_agent(DetectiveId, _),
    !.
create_match(ThiefId, DetectiveId, Scenario, Outcome) :-
    db:get_agent(ThiefId, Thief),
    db:get_agent(DetectiveId, Detective),
    check_roles(Thief, Detective, ThiefId, DetectiveId, Scenario, Outcome).

check_roles(Thief, Detective, ThiefId, DetectiveId, Scenario, Outcome) :-
    agent_has_role(Thief, thief),
    agent_has_role(Detective, detective),
    !,
    enqueue(ThiefId, DetectiveId, Scenario, Outcome).
check_roles(_, _, _, _, _, invalid_roles).

% Apenas ENFILEIRA: cria a linha pendente e devolve o id; a execucao acontece em
% background, num subprocesso, gerida por match_queue.
enqueue(ThiefId, DetectiveId, Scenario, Outcome) :-
    catch(enqueue_ok(ThiefId, DetectiveId, Scenario, Outcome),
          Error,
          enqueue_error(ThiefId, DetectiveId, Error, Outcome)).

enqueue_ok(ThiefId, DetectiveId, Scenario, created(MatchId)) :-
    engine:enqueue_match(ThiefId, DetectiveId, Scenario, MatchId).

enqueue_error(ThiefId, DetectiveId, Error, enqueue_failed) :-
    format(user_error,
           '[match] erro ao enfileirar ladrao=~w detective=~w: ~q~n',
           [ThiefId, DetectiveId, Error]).

%!  agent_has_role(+Agent, +Role) is semidet.   [(Role: thief | detective)
agent_has_role(Agent, Role) :-
    role_to_atom(Agent.role, RoleAtom),
    RoleAtom == Role.

role_to_atom(Role, Role) :- atom(Role), !.
role_to_atom(Role, Atom) :- atom_string(Atom, Role).

%!  eligible_rosters(-Thieves, -Detectives) is det.
%
%   Agentes elegiveis para cada papel, para montar os selects do formulario de
%   nova partida.
eligible_rosters(Thieves, Detectives) :-
    db:list_agents(Agents),
    include(has_role(thief), Agents, Thieves),
    include(has_role(detective), Agents, Detectives).

has_role(Role, Agent) :- agent_has_role(Agent, Role).

%!  list_page(+Page, +PerPage, -Matches, -Pagination) is det.
%   Uma pagina de partidas (leitura direta, sem regra).
list_page(Page, PerPage, Matches, Pagination) :-
    db:list_matches_page(Page, PerPage, Matches, Pagination).

%!  find_match(+Id, -Match) is semidet.
%   A partida pelo id, ou falha se nao existir.
find_match(Id, Match) :-
    db:get_match(Id, Match).

%!  match_detail(+Id, -Outcome) is det.
%
%   Resolve a partida e o estado a ser exibido. Outcome:
%     - done(Match)                      : concluida (replay completo disponivel)
%     - progress(Match, Status, Elapsed) : na fila/executando/falha; Elapsed em
%                                          segundos (do job ativo) ou "-"
%     - not_found
match_detail(Id, Outcome) :-
    db:get_match(Id, Match),
    !,
    match_progress(Id, Match, Outcome).
match_detail(_Id, not_found).

match_progress(_Id, Match, done(Match)) :-
    Match.status == "done",
    !.
match_progress(_Id, Match, progress(Match, Status, Elapsed)) :-
    engine:job_info(Match.id, Info),
    !,
    Status = Info.status,
    Elapsed = Info.elapsed_seconds.
match_progress(_Id, Match, progress(Match, Status, "-")) :-
    Status = Match.status.

%!  agent_display_name(+AgentId, -Name) is det.
%   Nome do agente, ou o proprio id quando nao encontrado.
agent_display_name(AgentId, Name) :-
    db:get_agent(AgentId, Agent),
    !,
    Name = Agent.name.
agent_display_name(AgentId, AgentId).

%!  decode_replay(+ReplayJson, -Replay) is det.
%   Decodifica o replay persistido; dict vazio se faltar ou estiver corrompido.
decode_replay(ReplayJson, Replay) :-
    catch(atom_json_dict(ReplayJson, Replay, []), _, fail),
    is_dict(Replay),
    !.
decode_replay(_ReplayJson, _{}).
