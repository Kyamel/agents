:- module(api_agents_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../security/authz').
:- use_module('../../json_request').
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').

:- http_handler(root(api/v1/agents), handler, [methods([get, post, options])]).

handler(Request) :-
    api_handle(Request, [get, post, options], dispatch).

dispatch(get, _Request) :-
    db:list_agents(Agents),
    reply_json(200, _{agents: Agents}).
dispatch(post, Request) :-
    authz:require_bearer_token(Request, UserId),
    catch(create_agent(UserId, Request, Status, Payload),
          Error,
          create_error(Error, Status, Payload)),
    reply_json(Status, Payload).

% =============================
% Logica (validacao + DB)
% =============================

create_agent(UserId, _, 403, _{error: "email_not_verified_or_user_not_found"}) :-
    \+ verified_user(UserId),
    !.
create_agent(UserId, Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, name, Name),
    json_request:require_string(Body, role, Role),
    json_request:require_string(Body, source, Source),
    create_validated(UserId, Name, Role, Source, Status, Payload).

create_validated(_UserId, Name, _Role, _Source, 422, _{error: "invalid_agent_name"}) :-
    \+ engine:valid_agent_name(Name),
    !.
create_validated(UserId, Name, Role, Source, 201, _{status: "created", agent: Agent}) :-
    id_string(UserId, UserIdStr),
    engine:register_agent_source(UserIdStr, Name, Role, Source, Agent).

% Traduz erros do registro para respostas HTTP. Corpo invalido ja vem como
% http_reply(bad_request(...)) (400) e segue direto para o framework.
create_error(http_reply(Reply), _, _) :-
    !,
    throw(http_reply(Reply)).
create_error(error(domain_error(role, _), _), 422,
             _{error: "invalid_role"}) :- !.
create_error(Error, 500, _{error: "internal_error"}) :-
    print_message(error, Error).

verified_user(UserId) :-
    db:find_user_by_id(UserId, User),
    User.is_verified == true.

id_string(Id, Id) :- string(Id), !.
id_string(Id, Str) :- atom(Id), !, atom_string(Id, Str).
id_string(Id, Str) :- term_string(Id, Str).
