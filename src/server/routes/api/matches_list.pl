:- module(api_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../http/api_endpoint').
:- use_module('../../http/authz').
:- use_module('../../http/json_request').
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').
:- use_module('../../../config').

:- http_handler(root(api/v1/matches), handler, [methods([get, post, options])]).

handler(Request) :-
    api_handle(Request, [get, post, options], dispatch).

dispatch(get, Request) :-
    http_parameters(Request, [
        page(Page0, [integer, default(1)]),
        perPage(PerPage0, [integer, default(10)])
    ]),
    clamp_pagination(Page0, PerPage0, Page, PerPage),
    db:list_matches_page(Page, PerPage, Matches, Pagination),
    reply_json(200, _{matches: Matches, pagination: Pagination}).
dispatch(post, Request) :-
    authz:require_bearer_token(Request, _UserId),
    catch(create_match(Request, Status, Payload),
          Error,
          api_error(Error, Status, Payload)),
    reply_json(Status, Payload).

% =============================
% Logica (validacao + enfileiramento)
% =============================
%
% A partida nao roda na request: ela e enfileirada e executada em background num
% subprocesso (ver engine/engine). A resposta e 202 com o id da partida; o
% progresso e consultado em GET /api/v1/jobs/<id> e o resultado em
% GET /api/v1/matches/<id>.

create_match(Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    require_id(Body, thief_agent_id, ThiefId),
    require_id(Body, detective_agent_id, DetectiveId),
    scenario_of(Body, Scenario),
    validate_and_enqueue(ThiefId, DetectiveId, Scenario, Status, Payload).

validate_and_enqueue(ThiefId, _, _, 404, _{error: "thief_agent_not_found"}) :-
    \+ db:get_agent(ThiefId, _),
    !.
validate_and_enqueue(_, DetectiveId, _, 404, _{error: "detective_agent_not_found"}) :-
    \+ db:get_agent(DetectiveId, _),
    !.
validate_and_enqueue(_, _, Scenario, 422, _{error: "invalid_scenario"}) :-
    \+ engine:valid_scenario(Scenario),
    !.
validate_and_enqueue(ThiefId, DetectiveId, Scenario, Status, Payload) :-
    db:get_agent(ThiefId, Thief),
    db:get_agent(DetectiveId, Detective),
    enqueue_if_roles_ok(ThiefId, DetectiveId, Thief, Detective, Scenario, Status, Payload).

enqueue_if_roles_ok(_, _, Thief, Detective, _, 422, _{error: "invalid_agent_roles"}) :-
    \+ valid_roles(Thief, Detective),
    !.
enqueue_if_roles_ok(ThiefId, DetectiveId, _, _, Scenario, 202,
                    _{status: "queued", match_id: MatchId}) :-
    engine:enqueue_match(ThiefId, DetectiveId, Scenario, MatchId).

valid_roles(Thief, Detective) :-
    Thief.role == "thief",
    Detective.role == "detective".

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
