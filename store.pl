:- module(store, [
    save_agent/2,
    get_agent/2,
    list_agents/1,

    save_match/2,
    get_match/2,
    list_matches/1
]).

:- use_module(library(uuid)).
:- use_module(library(lists)).

:- dynamic agent_record/2.
:- dynamic match_record/2.

% -----------------------------
% Agents
% -----------------------------

save_agent(Agent, SavedAgent) :-
    uuid(Id),
    atom_string(Id, IdStr),
    SavedAgent = Agent.put(_{
        id: IdStr
    }),
    assertz(agent_record(Id, SavedAgent)).

get_agent(Id, Agent) :-
    agent_record(Id, Agent).

list_agents(Agents) :-
    findall(Agent, agent_record(_, Agent), Agents).

% -----------------------------
% Matches
% -----------------------------

save_match(Match, SavedMatch) :-
    uuid(Id),
    atom_string(Id, IdStr),
    SavedMatch = Match.put(_{
        id: IdStr
    }),
    assertz(match_record(Id, SavedMatch)).

get_match(Id, Match) :-
    match_record(Id, Match).

list_matches(Matches) :-
    findall(Match, match_record(_, Match), Matches).
