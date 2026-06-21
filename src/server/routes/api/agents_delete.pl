:- module(api_agents_delete, []).

:- use_module('../../framework/endpoint').
:- use_module('../../../services/agents').

% Endpoint JSON de exclusao de agente. Toda a regra mora no service; aqui so
% declaramos o contrato (ver framework/endpoint.pl). O `Id` e variavel de
% segmento, entao a rota convive com o prefixo /api/v1/agents/ do agents_show.

style(json).
endpoint_methods([post, delete, options]).
endpoint_path(root(api/v1/agents/Id/delete), [id-Id]).
endpoint_auth(bearer).

handle(_Request, User, Params, Outcome) :-
    agents_service:delete_agent(User, Params.id, Outcome).

render(deleted(Id), json(200, _{status: "deleted", id: Id})).
render(forbidden,   json(403, _{error: "forbidden"})).
render(not_found,   json(404, _{error: "agent_not_found"})).

:- endpoint:mount(api_agents_delete).
