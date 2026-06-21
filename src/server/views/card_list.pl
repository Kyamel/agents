:- module(card_list, [
    card_grid/5
]).

:- use_module(library(apply)).
:- use_module(page_section).

% Renderiza uma coleção como grid de cards, caindo num estado vazio quando não
% há itens. Centraliza o padrão repetido nas telas de listagem (agentes,
% partidas): cada uma só fornece o renderizador do card, as classes do grid e o
% texto de vazio.
%
% Uso:
%   card_grid(Agents, agent_card_render(User),
%             'grid sm:grid-cols-2 gap-4', 'Nenhum agente.', Html)
% onde agent_card_render(+User, +Agent, -Card).

:- meta_predicate card_grid(+, 2, +, +, -).

card_grid([], _Render, _GridClass, EmptyText, Html) :-
    !,
    page_section:empty_state(EmptyText, Html).
card_grid(Items, Render, GridClass, _EmptyText, div([class(GridClass)], Cards)) :-
    maplist(Render, Items, Cards).
