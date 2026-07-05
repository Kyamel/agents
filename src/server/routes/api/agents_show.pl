:- module(api_agents_show, []).

:- use_module(library(http/http_parameters)).
:- use_module('../../http/api_endpoint').
:- use_module('../../../services/agents').

% `Id` e variavel de segmento; a rota convive com /api/v1/agents (lista) e
% /api/v1/agents/<id>/delete, resolvidos por especificidade pelo dispatch.
path(root(api/v1/agents/Id), [id-Id]).
accept(get, none).

handle(get, Request, _User, Params, Outcome) :-
    http_parameters(Request, [
        page(Page0, [integer, default(1)]),
        perPage(PerPage0, [integer, default(10)])
    ]),
    Page is max(1, Page0),
    PerPage is max(1, min(100, PerPage0)),
    agents:profile_page(Params.id, Page, PerPage, Outcome).

render(_Request, profile(Agent, Owner, Stats, Matches, Pagination),
       json(200, _{
           agent: Agent,
           owner: Owner,
           stats: Stats,
           matches: Matches,
           pagination: Pagination
       })).
render(_Request, not_found,
       json(404, _{error: "agent_not_found"})).

:- api_endpoint:mount(api_agents_show).
