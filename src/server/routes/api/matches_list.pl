:- module(api_matches_list, []).

:- use_module(library(http/http_parameters)).
:- use_module('../../http/api_endpoint').
:- use_module('../../http/json_request').
:- use_module('../../../config').
:- use_module('../../../services/matches').

% GET e publico; POST exige bearer. O recipe resolve auth por metodo.
path(root(api/v1/matches), []).
accept(get, none).
accept(post, bearer).

handle(get, Request, _User, _Params, matches(Matches, Pagination)) :-
    http_parameters(Request, [
        page(Page0, [integer, default(1)]),
        perPage(PerPage0, [integer, default(10)])
    ]),
    clamp_pagination(Page0, PerPage0, Page, PerPage),
    matches:list_page(Page, PerPage, Matches, Pagination).
handle(post, Request, _User, _Params, Outcome) :-
    json_request:read_json_body(Request, Body),
    require_id(Body, thief_agent_id, ThiefId),
    require_id(Body, detective_agent_id, DetectiveId),
    scenario_of(Body, Scenario),
    matches:create_match(ThiefId, DetectiveId, Scenario, Outcome).

render(_Request, matches(Matches, Pagination),
       json(200, _{matches: Matches, pagination: Pagination})).
render(_Request, created(MatchId),
       json(202, _{status: "queued", match_id: MatchId})).
render(_Request, missing_agents,
       json(400, _{error: "missing_agents"})).
render(_Request, thief_not_found,
       json(404, _{error: "thief_agent_not_found"})).
render(_Request, detective_not_found,
       json(404, _{error: "detective_agent_not_found"})).
render(_Request, invalid_scenario,
       json(422, _{error: "invalid_scenario"})).
render(_Request, invalid_roles,
       json(422, _{error: "invalid_agent_roles"})).
render(_Request, enqueue_failed,
       json(500, _{error: "match_enqueue_failed"})).

% Cenario opcional no corpo; cai no padrao configurado quando ausente.
scenario_of(Body, Scenario) :-
    get_dict(scenario, Body, Scenario),
    string(Scenario),
    Scenario \== "",
    !.
scenario_of(_Body, Scenario) :-
    config:engine_scenario(Scenario).

require_id(Body, Key, Id) :-
    get_dict(Key, Body, Value),
    id_value(Value, Id),
    !.
require_id(_, Key, _) :-
    format(string(Message), "Missing or invalid id field: ~w", [Key]),
    throw(http_reply(bad_request(_{error: Message}))).

id_value(Value, Value) :-
    integer(Value),
    Value > 0,
    !.
id_value(Value, Value) :-
    string(Value),
    Value \== "",
    !.

clamp_pagination(Page0, PerPage0, Page, PerPage) :-
    Page is max(1, Page0),
    PerPage is max(1, min(100, PerPage0)).

:- api_endpoint:mount(api_matches_list).
