:- module(api_agents_delete, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../../services/agents').

path(root(api/v1/agents/Id/delete), [id-Id]).
accept(post, bearer).
accept(delete, bearer).

handle(_Method, _Request, User, Params, Outcome) :-
    agents:delete_agent(User, Params.id, Outcome).

render(_Request, deleted(Id), json(200, _{status: "deleted", id: Id})).
render(_Request, forbidden,   json(403, _{error: "forbidden"})).
render(_Request, not_found,   json(404, _{error: "agent_not_found"})).

:- api_endpoint:mount(api_agents_delete).
