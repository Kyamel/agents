:- module(api_agents, [
    handler/1
  ]).


:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).

handler(Request) :-
    cors_enable,
    memberchk(method(Method), Request),
    agents_handler_method(Method, Request).

agents_handler_method(get, _Request) :-
    store:list_agents(Agents),
    reply_json_dict(_{
        agents: Agents
    }).

agents_handler_method(post, Request) :-
    http_read_json_dict(Request, Body),
    create_agent_from_body(Body, Agent),
    store:save_agent(Agent, SavedAgent),
    reply_json_dict(_{
        status: "created",
        agent: SavedAgent
    }, [status(201)]).

agents_handler_method(_, _) :-
    reply_json_dict(_{
        error: "method_not_allowed"
    }, [status(405)]).

create_agent_from_body(Body, Agent) :-
    require_string(Body, name, Name),
    require_string(Body, role, Role),
    require_string(Body, module, Module),
    require_string(Body, predicate, Predicate),

    valid_role(Role),

    Agent = _{
        name: Name,
        role: Role,
        module: Module,
        predicate: Predicate
    }.

valid_role("thief").
valid_role("detective").

