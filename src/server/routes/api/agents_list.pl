:- module(api_agents_list, []).

:- use_module(library(http/http_parameters)).
:- use_module('../../http/api_endpoint').
:- use_module('../../http/json_request').
:- use_module('../../../services/agents').
:- use_module('../../../engine/engine').

% GET e publico (lista paginada); POST exige bearer e cria um agente.
path(root(api/v1/agents), []).
accept(get, none).
accept(post, bearer).

handle(get, Request, _User, _Params, agents(Agents, Pagination)) :-
    http_parameters(Request, [
        page(Page0, [integer, default(1)]),
        perPage(PerPage0, [integer, default(10)])
    ]),
    clamp_pagination(Page0, PerPage0, Page, PerPage),
    agents:list_page(Page, PerPage, Agents, Pagination).
handle(post, Request, User, _Params, Outcome) :-
    create_agent(User, Request, Outcome).

render(_Request, agents(Agents, Pagination),
       json(200, _{agents: Agents, pagination: Pagination})).
render(_Request, created(Agent),
       json(201, _{status: "created", agent: Agent})).
render(_Request, email_not_verified,
       json(403, _{error: "email_not_verified_or_user_not_found"})).
render(_Request, invalid_role,
       json(422, _{error: "invalid_role"})).
render(_Request, missing_module_directive,
       json(422, _{error: "missing_module_directive"})).
render(_Request, invalid_agent_module_name,
       json(422, _{error: "invalid_agent_module_name"})).
render(_Request, invalid_prolog_source,
       json(422, _{error: "invalid_prolog_source"})).

create_agent(User, _Request, email_not_verified) :-
    User.is_verified \== true,
    !.
create_agent(User, Request, Outcome) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, role, Role),
    json_request:require_string(Body, source, Source),
    optional_private(Body, IsPrivate),
    id_string(User.id, UserIdStr),
    catch(register(UserIdStr, Role, Source, IsPrivate, Outcome),
          Error,
          register_error(Error, Outcome)).

register(UserIdStr, Role, Source, IsPrivate, created(Agent)) :-
    engine:register_agent_source_from_module(UserIdStr, Role, Source, IsPrivate, Agent).

% Traduz erros especificos do registro para outcomes; corpo invalido (http_reply)
% e o resto sobem e caem no tratamento comum de api_endpoint.
register_error(error(domain_error(role, _), _), invalid_role) :- !.
register_error(error(domain_error(agent_module_directive, _), _),
               missing_module_directive) :- !.
register_error(error(domain_error(agent_name, _), _),
               invalid_agent_module_name) :- !.
register_error(error(syntax_error(_), _), invalid_prolog_source) :- !.
register_error(Error, _) :- throw(Error).

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

:- api_endpoint:mount(api_agents_list).
