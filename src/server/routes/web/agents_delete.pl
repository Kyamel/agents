:- module(route_agents_delete, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../http/web_session').
:- use_module('../../../services/agents').

% Endpoint web de exclusao de agente. Mesma logica do service que a API usa; muda
% so a auth (cookie de sessao) e o formato da resposta (status puro, sem JSON). O
% botao no card faz um fetch DELETE aqui e remove o cartao no 200.
:- http_handler(root(agents/Id/delete), handler(Id), [methods([post, delete])]).

handler(Id, Request) :-
    web_session:require_user(Request, User),
    agents:delete_agent(User, Id, Outcome),
    reply(Outcome).

reply(deleted(_)) :-
    format("Status: 200 OK~n"),
    format("Content-Type: text/html; charset=UTF-8~n~n").
reply(forbidden) :-
    reply_text(403, "Sem permissão para excluir este agente.").
reply(not_found) :-
    reply_text(404, "Agente não encontrado.").

reply_text(Status, Text) :-
    format("Status: ~w~n", [Status]),
    format("Content-Type: text/plain; charset=UTF-8~n~n"),
    format("~w~n", [Text]).
