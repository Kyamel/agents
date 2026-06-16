:- module(api_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../security/authz').
:- use_module('../../json_request').
:- use_module('../../../db/sqlite_store').
:- use_module('../../../engine/match_runner').
:- use_module('../../../engine/match_queue').
:- use_module('../../../config').

:- http_handler(root(api/v1/matches), handler, [methods([get, post, options])]).

handler(Request) :-
    api_handle(Request, [get, post, options], dispatch).

dispatch(get, _Request) :-
    sqlite_store:list_matches(Matches),
    reply_json(200, _{matches: Matches}).
dispatch(post, Request) :-
    authz:require_bearer_token(Request, _UserId),
    catch(create_match(Request, Status, Payload),
          Error,
          create_error(Error, Status, Payload)),
    reply_json(Status, Payload).

% =============================
% Logica (validacao + enfileiramento)
% =============================
%
% A partida nao roda na request: ela e enfileirada e executada em background num
% subprocesso (ver engine/match_queue). A resposta e 202 com o id da partida; o
% progresso e consultado em GET /api/v1/jobs/<id> e o resultado em
% GET /api/v1/matches/<id>.

create_match(Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, thief_agent_id, ThiefId),
    json_request:require_string(Body, detective_agent_id, DetectiveId),
    scenario_of(Body, Scenario),
    validate_and_enqueue(ThiefId, DetectiveId, Scenario, Status, Payload).

validate_and_enqueue(ThiefId, _, _, 404, _{error: "thief_agent_not_found"}) :-
    \+ sqlite_store:get_agent(ThiefId, _),
    !.
validate_and_enqueue(_, DetectiveId, _, 404, _{error: "detective_agent_not_found"}) :-
    \+ sqlite_store:get_agent(DetectiveId, _),
    !.
validate_and_enqueue(_, _, Scenario, 422, _{error: "invalid_scenario"}) :-
    \+ match_runner:valid_scenario(Scenario),
    !.
validate_and_enqueue(ThiefId, DetectiveId, Scenario, Status, Payload) :-
    sqlite_store:get_agent(ThiefId, Thief),
    sqlite_store:get_agent(DetectiveId, Detective),
    enqueue_if_roles_ok(ThiefId, DetectiveId, Thief, Detective, Scenario, Status, Payload).

enqueue_if_roles_ok(_, _, Thief, Detective, _, 422, _{error: "invalid_agent_roles"}) :-
    \+ valid_roles(Thief, Detective),
    !.
enqueue_if_roles_ok(ThiefId, DetectiveId, _, _, Scenario, 202,
                    _{status: "queued", match_id: MatchId}) :-
    match_queue:enqueue_match(ThiefId, DetectiveId, Scenario, MatchId).

valid_roles(Thief, Detective) :-
    Thief.role == "thief",
    Detective.role == "detective".

%!  scenario_of(+Body, -Scenario) is det.
%
%   Cenario opcional no corpo; cai no padrao configurado quando ausente.
scenario_of(Body, Scenario) :-
    get_dict(scenario, Body, Scenario),
    string(Scenario),
    Scenario \== "",
    !.
scenario_of(_Body, Scenario) :-
    config:engine_scenario(Scenario).

create_error(http_reply(Reply), _, _) :-
    !,
    throw(http_reply(Reply)).
create_error(Error, 500, _{error: "internal_error"}) :-
    print_message(error, Error).
