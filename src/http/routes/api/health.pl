:- module(api_health, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_cors)).

:- http_handler(root(health), health_handler, [method(get)]).

%!  health_handler(+Request) is det.
%
%   Responde health-check do serviço.
health_handler(Request) :-
    cors_enable(Request, [methods([get, options])]),
    reply_json_dict(_{
        status: "ok",
        service: "agents-battle-api"
    }).
