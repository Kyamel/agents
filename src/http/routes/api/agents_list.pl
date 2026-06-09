:- module(api_agents_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module('../../security/rate_limit').
:- use_module('../../security/authz').
:- use_module('../../controller/json_request').
:- use_module('../../../db/sqlite_store').
:- use_module('../../../engine/registry').

:- http_handler(root(api/v1/agents), handler, [methods([get, post, options])]).

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
    sqlite_store:list_agents(Agents),
    reply(200, _{agents: Agents}).
dispatch(post, Request) :-
    authz:require_bearer_token(Request, UserId),
    catch(create_agent(UserId, Request, Status, Payload),
          Error,
          create_error(Error, Status, Payload)),
    reply(Status, Payload).
dispatch(_, _) :-
    reply(405, _{error: "method_not_allowed"}).

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
    \+ valid_name(Name),
    !.
create_validated(UserId, Name, Role, Source, 201, _{status: "created", agent: Agent}) :-
    id_string(UserId, UserIdStr),
    agent_registry:register_agent_source(UserIdStr, Name, Role, Source, Agent).

%!  valid_name(+Name) is semidet.
%
%   Nome deve ser um slug ASCII: minusculas, digitos e hifens, com ao menos
%   um caractere alfanumerico.
valid_name(Name) :-
    string_codes(Name, Codes),
    forall(member(C, Codes), slug_code(C)),
    once((member(A, Codes), alnum_code(A))).

slug_code(0'-) :- !.
slug_code(C) :- alnum_code(C).

alnum_code(C) :- C >= 0'a, C =< 0'z, !.
alnum_code(C) :- C >= 0'0, C =< 0'9.

%!  create_error(+Error, -Status, -Payload) is det.
%
%   Traduz erros de validacao do registro para respostas HTTP limpas.
create_error(error(domain_error(role, _), _), 422,
             _{error: "invalid_role"}) :- !.
create_error(Error, 500, _{error: "internal_error"}) :-
    print_message(error, Error).

verified_user(UserId) :-
    sqlite_store:find_user_by_id(UserId, User),
    User.is_verified == true.

id_string(Id, Id) :- string(Id), !.
id_string(Id, Str) :- atom(Id), !, atom_string(Id, Str).
id_string(Id, Str) :- term_string(Id, Str).

% =============================
% Resposta (JSON)
% =============================

reply(Status, Payload) :-
    reply_json_dict(Payload, [status(Status)]).
