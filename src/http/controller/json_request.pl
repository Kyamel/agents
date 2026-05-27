:- module(json_request, [
    read_json_body/2,
    require_string/3
]).

:- use_module(library(http/http_json)).

%!  read_json_body(+Request, -Body) is det.
%
%   Le corpo JSON da requisicao ou lanca 400.
read_json_body(Request, Body) :-
    catch(http_read_json_dict(Request, Body), _, fail),
    !.
read_json_body(_, _) :-
    throw(http_reply(bad_request(_{error: "invalid_json_body"}))).

%!  require_string(+Dict, +Key, -Value) is det.
%
%   Extrai campo string obrigatorio do corpo JSON; lanca 400 em ausencia.
require_string(Dict, Key, Value) :-
    get_dict(Key, Dict, Value),
    string(Value),
    Value \= "",
    !.
require_string(_, Key, _) :-
    format(string(Message), "Missing or invalid string field: ~w", [Key]),
    throw(http_reply(bad_request(_{error: Message}))).
