:- module(matches_orchestrator, [
    list_matches/1,
    create_match_from_request/2
]).

:- use_module(library(http/http_json)).
:- use_module('../../db/sqlite_store', []).
:- use_module('../../engine/match_runner').

%!  list_matches(-Matches) is det.
%
%   Lista partidas persistidas para resposta de API.
list_matches(Matches) :-
    sqlite_store:list_matches(Matches).

%!  create_match_from_request(+Request, -Payload) is det.
%
%   Valida payload, executa partida e retorna payload de criação.
create_match_from_request(Request, Payload) :-
    read_json_body(Request, Body),
    require_string(Body, thief_agent_id, ThiefId),
    require_string(Body, detective_agent_id, DetectiveId),

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

%!  ensure_roles(+Thief, +Detective) is det.
%
%   Garante combinação de papéis thief/detective para criação de partida.
ensure_roles(Thief, Detective) :-
    Thief.role == "thief",
    Detective.role == "detective",
    !.
ensure_roles(_, _) :-
    throw(http_reply(bad_request(_{error: "invalid_agent_roles"}))).

%!  require_string(+Dict, +Key, -Value) is det.
%
%   Extrai campo string obrigatório de dict JSON.
require_string(Dict, Key, Value) :-
    get_dict(Key, Dict, Value),
    string(Value),
    Value \= "",
    !.
require_string(_, Key, _) :-
    format(string(Message), "Missing or invalid string field: ~w", [Key]),
    throw(http_reply(bad_request(_{error: Message}))).

%!  read_json_body(+Request, -Body) is det.
%
%   Lê JSON da requisição ou lança erro 400.
read_json_body(Request, Body) :-
    catch(http_read_json_dict(Request, Body), _, fail),
    !.
read_json_body(_, _) :-
    throw(http_reply(bad_request(_{error: "invalid_json_body"}))).

%!  ensure_agent_exists(+AgentId, +RoleLabel, -Agent) is det.
%
%   Recupera agente por ID ou lança erro 404 específico por papel.
ensure_agent_exists(AgentId, RoleLabel, Agent) :-
    (   sqlite_store:get_agent(AgentId, Agent)
    ->  true
    ;   role_not_found_error(RoleLabel, Message),
        throw(http_reply(not_found(_{error: Message})))
    ).

%!  role_not_found_error(+RoleLabel, -Message) is det.
%
%   Mapeia papel para mensagem de erro de agente ausente.
role_not_found_error(thief, "thief_agent_not_found").
role_not_found_error(detective, "detective_agent_not_found").
