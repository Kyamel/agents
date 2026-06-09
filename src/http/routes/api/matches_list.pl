:- module(api_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../json_request').
:- use_module('../../../db/sqlite_store').
:- use_module('../../../engine/match_runner').

:- http_handler(root(api/v1/matches), handler, [methods([get, post, options])]).

% =============================
% Handler
% =============================

handler(Request) :-
    cors_enable(Request, [methods([get, post, options])]),
    rate_limit:enforce_ip_rate_limit(Request),
    memberchk(method(Method), Request),
    dispatch(Method, Request).

dispatch(options, _) :-
    format("Content-type: text/plain~n~n").
dispatch(get, _Request) :-
    sqlite_store:list_matches(Matches),
    reply(200, _{matches: Matches}).
dispatch(post, Request) :-
    create_match(Request, Payload),
    reply(201, Payload).
dispatch(_, _) :-
    reply(405, _{error: "method_not_allowed"}).

% =============================
% Logica (validacao + execucao + DB)
% =============================

create_match(Request, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, thief_agent_id, ThiefId),
    json_request:require_string(Body, detective_agent_id, DetectiveId),
    ensure_agent_exists(ThiefId, thief, Thief),
    ensure_agent_exists(DetectiveId, detective, Detective),
    ensure_roles(Thief, Detective),
    match_runner:run_match(Thief, Detective, MatchResult, ReplayJson),
    sqlite_store:save_match(ThiefId, DetectiveId, MatchResult.winner, ReplayJson, MatchId),
    Payload = _{
        status: "finished",
        match_id: MatchId,
        match: MatchResult
    }.

ensure_agent_exists(AgentId, _, Agent) :-
    sqlite_store:get_agent(AgentId, Agent),
    !.
ensure_agent_exists(_, RoleLabel, _) :-
    role_not_found_error(RoleLabel, Message),
    throw(http_reply(not_found(_{error: Message}))).

role_not_found_error(thief, "thief_agent_not_found").
role_not_found_error(detective, "detective_agent_not_found").

ensure_roles(Thief, Detective) :-
    Thief.role == "thief",
    Detective.role == "detective",
    !.
ensure_roles(_, _) :-
    throw(http_reply(bad_request(_{error: "invalid_agent_roles"}))).

% =============================
% Resposta (JSON)
% =============================

reply(Status, Payload) :-
    reply_json_dict(Payload, [status(Status)]).
