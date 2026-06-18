:- module(api_agents_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../components/api_endpoint').
:- use_module('../../security/authz').
:- use_module('../../json_request').
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').

:- http_handler(root(api/v1/agents), handler, [methods([get, post, options])]).

handler(Request) :-
    api_handle(Request, [get, post, options], dispatch).

dispatch(get, Request) :-
    http_parameters(Request, [
        page(Page0, [integer, default(1)]),
        perPage(PerPage0, [integer, default(10)])
    ]),
    clamp_pagination(Page0, PerPage0, Page, PerPage),
    db:list_agents_page(Page, PerPage, Agents, Pagination),
    reply_json(200, _{agents: Agents, pagination: Pagination}).
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
    json_request:require_string(Body, role, Role),
    json_request:require_string(Body, source, Source),
    optional_private(Body, IsPrivate),
    create_validated(UserId, Role, Source, IsPrivate, Status, Payload).

create_validated(UserId, Role, Source, IsPrivate, 201, _{status: "created", agent: Agent}) :-
    id_string(UserId, UserIdStr),
    engine:register_agent_source_from_module(UserIdStr, Role, Source, IsPrivate, Agent).

% Traduz erros especificos do registro; o resto (corpo invalido, 500) cai no
% tratamento comum de api_endpoint:api_error/3.
create_error(error(domain_error(role, _), _), 422,
             _{error: "invalid_role"}) :- !.
create_error(error(domain_error(agent_module_directive, _), _), 422,
             _{error: "missing_module_directive"}) :- !.
create_error(error(domain_error(agent_name, _), _), 422,
             _{error: "invalid_agent_module_name"}) :- !.
create_error(error(syntax_error(_), _), 422,
             _{error: "invalid_prolog_source"}) :- !.
create_error(Error, Status, Payload) :-
    api_error(Error, Status, Payload).

verified_user(UserId) :-
    db:find_user_by_id(UserId, User),
    User.is_verified == true.

id_string(Id, Id) :- string(Id), !.
id_string(Id, Str) :- atom(Id), !, atom_string(Id, Str).
id_string(Id, Str) :- term_string(Id, Str).

optional_private(Body, IsPrivate) :-
    get_dict(private, Body, Value),
    !,
    json_bool(Value, IsPrivate).
optional_private(_, false).

json_bool(true, true) :- !.
json_bool(false, false) :- !.
json_bool(_, _) :-
    throw(http_reply(bad_request(_{error: "Field private must be boolean"}))).

clamp_pagination(Page0, PerPage0, Page, PerPage) :-
    Page is max(1, Page0),
    PerPage is max(1, min(100, PerPage0)).
