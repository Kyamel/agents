:- module(api_agents_show, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../../services/agents').

% `Id` e variavel de segmento; a rota convive com /api/v1/agents (lista) e
% /api/v1/agents/<id>/delete, resolvidos por especificidade pelo dispatch.
path(root(api/v1/agents/Id), [id-Id]).
accept(get, none).

handle(get, _Request, _User, Params, Outcome) :-
    agents:public_view(Params.id, Outcome).

render(_Request, agent(Public), json(200, _{agent: Public})).
render(_Request, not_found,     json(404, _{error: "agent_not_found"})).

:- api_endpoint:mount(api_agents_show).
