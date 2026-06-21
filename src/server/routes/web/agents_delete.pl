:- module(route_agents_delete, []).

:- use_module('../../framework/endpoint').
:- use_module('../../../services/agents').

% Endpoint web de exclusao de agente. Mesma logica do service que a API usa; muda
% so a auth (cookie de sessao) e o formato da resposta. O botao no card faz um
% fetch DELETE aqui e remove o cartao no 200.

style(web).
endpoint_methods([post, delete]).
endpoint_path(root(agents/Id/delete), [id-Id]).
endpoint_auth(session).

handle(_Request, User, Params, Outcome) :-
    agents_service:delete_agent(User, Params.id, Outcome).

render(deleted(_), empty(200)).
render(forbidden,  text(403, "Sem permissao para excluir este agente.")).
render(not_found,  text(404, "Agente nao encontrado.")).

:- endpoint:mount(route_agents_delete).
