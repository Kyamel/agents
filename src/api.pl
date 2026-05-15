:- module(api, [server/1]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).
:- use_module(library(option)).
:- use_module(library(debug)).

:- use_module('store').
:- use_module('game').
:- use_module('routes/app/index').
:- use_module('routes/app/agents').
:- use_module('routes/api/agents').

% -----------------------------
% CORS
% -----------------------------
:- set_setting(http:cors, [*]).
:- http_handler(root(.), options_handler, [method(options), prefix]).
:- http_handler(root(health), health_handler, [method(get)]).

% ------------------------------
% APP
% ------------------------------
:- http_handler(root(.), home_handler, [method(get)]).
:- http_handler(root(agents), app_agents:agents_page, [method(get)]).

% -----------------------------
% API
% -----------------------------
:- http_handler(root(api/agents), api_agents:handler, [methods([get, post, options])]).
:- http_handler(root(api/matches), matches_handler, [methods([get, post, options])]).
:- http_handler(root(api/match/Id), match_handler(Id), [method(get)]).

% -----------------------------
% Server
% -----------------------------
server(Port) :-
    http_server(http_dispatch, [port(Port)]).

  %:- initialization(main, main).

main(Argv) :-
    parse_port(Argv, Port),
    format("Prolog Yard API running on http://localhost:~w~n", [Port]),
    server(Port).

parse_port(Argv, Port) :-
    append(_, ['--port', PortAtom | _], Argv), !,
    atom_number(PortAtom, Port).

parse_port(_, 8080).

% -----------------------------
% Common handlers
% -----------------------------
options_handler(Request) :-
    cors_enable(Request, [methods([get, post, put, delete, options])]),
    format("~n").

health_handler(_Request) :-
    cors_enable,
    reply_json_dict(_{
        status: "ok",
        service: "prolog-yard"
    }).

% -----------------------------
% /
% -----------------------------
home_handler(_Request) :-
    app_index:index_page(_Request).

% -----------------------------
% /matches
% -----------------------------
matches_handler(Request) :-
    debug(api, "matches_handler called, request: ~w", [Request]),
    cors_enable,
    memberchk(method(Method), Request),
    debug(api, "method: ~w", [Method]),
    matches_handler_method(Method, Request).

matches_handler_method(post, Request) :-
    debug(api, "post handler entered", []),
    http_read_json_dict(Request, Body),
    debug(api, "body: ~w", [Body]),
    require_string(Body, thief_agent_id, ThiefAgentId),
    debug(api, "thief_agent_id: ~w", [ThiefAgentId]),
    require_string(Body, detective_agent_id, DetectiveAgentId),
    debug(api, "detective_agent_id: ~w", [DetectiveAgentId]),
    store:get_agent(ThiefAgentId, ThiefAgent),
    debug(api, "thief_agent: ~w", [ThiefAgent]),
    store:get_agent(DetectiveAgentId, DetectiveAgent),
    debug(api, "detective_agent: ~w", [DetectiveAgent]),
    game:run_match(ThiefAgent, DetectiveAgent, MatchResult),
    debug(api, "match_result: ~w", [MatchResult]),
      store:save_match(MatchResult, SavedMatch),
      reply_json_dict(_{
          status: "finished",
          match: SavedMatch
      }, [status(201)]).

matches_handler_method(get, _Request) :-
    store:list_matches(Matches),
    reply_json_dict(_{
        matches: Matches
    }).

matches_handler_method(_, _) :-
    reply_json_dict(_{
        error: "method_not_allowed"
    }, [status(405)]).

% -----------------------------
% /match/:id
% -----------------------------

match_handler(Id, _Request) :-
    cors_enable,
    (   store:get_match(Id, Match)
    ->  reply_json_dict(_{
            match: Match
        })
    ;   reply_json_dict(_{
            error: "match_not_found",
            id: Id
        }, [status(404)])
    ).

% -----------------------------
% Validation helpers
% -----------------------------

require_string(Dict, Key, Value) :-
    get_dict(Key, Dict, Value),
    string(Value), !.

require_string(_, Key, _) :-
    format(string(Message), "Missing or invalid string field: ~w", [Key]),
    throw(http_reply(bad_request(_{error: Message}))).
