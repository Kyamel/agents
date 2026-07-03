:- module(api_users_show, []).

:- use_module(library(apply)).
:- use_module('../../http/api_endpoint').
:- use_module('../../../services/users').

path(root(api/v1/users/Id), [id-Id]).
accept(get, none).

handle(get, _Request, _User, Params, Outcome) :-
    load_profile(Params.id, Outcome).

render(_Request, profile(User, Stats, Agents),
       json(200, _{user: User, stats: Stats, agents: Agents})).
render(_Request, not_found, json(404, _{error: "user_not_found"})).

load_profile(Id, profile(PublicUser, GlobalStats, Agents)) :-
    users:profile(Id, profile(User, AgentStats, GlobalStats)),
    !,
    public_user(User, PublicUser),
    maplist(agent_with_stats, AgentStats, Agents).
load_profile(_, not_found).

public_user(User, Public) :-
    Public = _{
        id: User.id,
        username: User.username,
        email: User.email,
        is_verified: User.is_verified,
        created_at: User.created_at
    }.

% Expoe as stats dentro do dict do agente (formato da API).
agent_with_stats(stat(Agent, Stats), Agent.put(stats, Stats)).

:- api_endpoint:mount(api_users_show).
