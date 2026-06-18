:- module(api_users_show, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../../db/db').

:- http_handler('/api/v1/users/', handler,
                [methods([get, options]), prefix]).

handler(Request) :-
    api_handle(Request, [get, options], dispatch).

dispatch(get, Request) :-
    memberchk(path(Path), Request),
    handle_get(Path).

handle_get(Path) :-
    extract_id(Path, Id),
    !,
    load_profile(Id, Status, Payload),
    reply_json(Status, Payload).
handle_get(_) :-
    reply_json(404, _{error: "not_found"}).

extract_id(Path, Id) :-
    atom_concat('/api/v1/users/', Id, Path),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_profile(Id, 200, _{user: PublicUser, stats: GlobalStats, agents: Agents}) :-
    db:find_user_by_id(Id, User),
    !,
    public_user(User, PublicUser),
    db:list_agents(AllAgents),
    include(owner_is(User.id), AllAgents, UserAgents),
    db:list_matches(Matches),
    maplist(agent_with_stats(Matches), UserAgents, Agents),
    aggregate_stats(Agents, GlobalStats).
load_profile(_, 404, _{error: "user_not_found"}).

public_user(User, Public) :-
    Public = _{
        id: User.id,
        username: User.username,
        email: User.email,
        is_verified: User.is_verified,
        created_at: User.created_at
    }.

owner_is(UserId, Agent) :-
    same_id(UserId, Agent.owner_user_id).

agent_with_stats(Matches, Agent, Agent.put(stats, Stats)) :-
    agent_stats(Agent.id, Matches, Stats).

agent_stats(AgentId, Matches, Stats) :-
    empty_stats(Initial),
    foldl(count_agent_match(AgentId), Matches, Initial, Stats).

count_agent_match(AgentId, Match, Stats0, Stats) :-
    match_result_for_agent(AgentId, Match, Result),
    !,
    increment_stat(Result, Stats0, Stats).
count_agent_match(_, _, Stats, Stats).

match_result_for_agent(AgentId, Match, Result) :-
    completed_match(Match),
    agent_role_in_match(AgentId, Match, Role),
    result_for_role(Role, Match.winner, Result).

completed_match(Match) :-
    Match.status == "done",
    Match.winner \== "",
    Match.winner \== '$null$'.

agent_role_in_match(AgentId, Match, thief) :-
    same_id(AgentId, Match.thief_agent_id),
    !.
agent_role_in_match(AgentId, Match, detective) :-
    same_id(AgentId, Match.detective_agent_id).

result_for_role(_, Winner, draw) :-
    same_text(Winner, "draw"),
    !.
result_for_role(Role, Winner, win) :-
    role_winner(Role, Winner),
    !.
result_for_role(_, _, loss).

role_winner(thief, Winner) :- same_text(Winner, "thief").
role_winner(detective, Winner) :- same_text(Winner, "detective").

aggregate_stats(Agents, Stats) :-
    empty_stats(Initial),
    foldl(add_agent_stats, Agents, Initial, Stats).

add_agent_stats(Agent, Stats0, Stats) :-
    add_stats(Stats0, Agent.stats, Stats).

empty_stats(_{wins:0, losses:0, draws:0}).

increment_stat(win, Stats0, Stats) :-
    Wins is Stats0.wins + 1,
    Stats = Stats0.put(wins, Wins).
increment_stat(loss, Stats0, Stats) :-
    Losses is Stats0.losses + 1,
    Stats = Stats0.put(losses, Losses).
increment_stat(draw, Stats0, Stats) :-
    Draws is Stats0.draws + 1,
    Stats = Stats0.put(draws, Draws).

add_stats(A, B, _{
    wins: Wins,
    losses: Losses,
    draws: Draws
}) :-
    Wins is A.wins + B.wins,
    Losses is A.losses + B.losses,
    Draws is A.draws + B.draws.

same_id(A, B) :-
    normalize_text(A, Text),
    normalize_text(B, Text).

same_text(A, B) :-
    normalize_text(A, Text),
    normalize_text(B, Text).

normalize_text(Value, Text) :-
    string(Value),
    !,
    Text = Value.
normalize_text(Value, Text) :-
    atom(Value),
    !,
    atom_string(Value, Text).
normalize_text(Value, Text) :-
    format(string(Text), "~w", [Value]).
