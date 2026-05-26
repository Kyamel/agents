:- module(agents_orchestrator, [
    list_agents/1,
    create_agent_from_request/4
]).

:- use_module(library(http/http_json)).
:- use_module('../../db/sqlite_store', []).
:- use_module('../../engine/registry').

%!  list_agents(-Agents) is det.
%
%   Lista agentes persistidos para resposta de API.
list_agents(Agents) :-
    sqlite_store:list_agents(Agents).

%!  create_agent_from_request(+UserId, +Request, -Status, -Payload) is det.
%
%   Valida usuário/corpo e registra agente, retornando status/payload HTTP.
create_agent_from_request(UserId, Request, Status, Payload) :-
    (   verified_user(UserId)
    ->  read_json_body(Request, Body),
        require_string(Body, name, Name),
        require_string(Body, role, Role),
        require_string(Body, source, Source),
        id_string(UserId, UserIdStr),
        agent_registry:register_agent_source(UserIdStr, Name, Role, Source, Agent),
        Status = 201,
        Payload = _{status: "created", agent: Agent}
    ;   Status = 403,
        Payload = _{error: "email_not_verified_or_user_not_found"}
    ).

%!  verified_user(+UserId) is semidet.
%
%   Sucede quando usuário existe e está verificado.
verified_user(UserId) :-
    sqlite_store:find_user_by_id(UserId, User),
    User.is_verified == true.

%!  id_string(+Id, -Str) is det.
%
%   Normaliza um identificador (átomo do banco ou string) para string.
id_string(Id, Str) :-
    (   string(Id)
    ->  Str = Id
    ;   atom(Id)
    ->  atom_string(Id, Str)
    ;   term_string(Id, Str)
    ).

%!  require_string(+Dict, +Key, -Value) is det.
%
%   Extrai campo string obrigatório de um dict JSON.
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
