:- module(route_agents_list, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../services/agents').
:- use_module('../../http/web_session').
:- use_module('../../views/page').
:- use_module('../../views/agent_card').
:- use_module('../../views/button_link').
:- use_module('../../views/card_list').
:- use_module('../../views/pagination').
:- use_module('../../views/page_section').

:- http_handler(root(agents), handler, [method(get)]).

handler(Request) :-
    web_session:current_user_or_anon(Request, User),
    http_parameters(Request, [page(Page0, [integer, default(1)])]),
    Page is max(1, Page0),
    agents:list_page_with_owners(Page, 10, AgentsRich, PaginationMeta),
    render_page(Request, User, AgentsRich, PaginationMeta).

render_page(Request, User, Agents, PaginationMeta) :-
    card_grid(Agents, render_card(User), 'grid sm:grid-cols-2 gap-3',
              'Nenhum agente cadastrado ainda.', ListHtml),
    pagination:pagination_nav('/agents', PaginationMeta, Pagination),
    button_link:auth_button_link(User, '/agents/new', 'Enviar agente', Cta),
    page_section:top_bar('Agentes', Cta, TopBar),
    page:reply_page(Request, 'Agentes', [
        TopBar,
        p([class('text-surface-400 mb-6')],
          'Agentes cadastrados na plataforma. Também disponível em /api/v1/agents.'),
        ListHtml,
        Pagination
    ]).

render_card(User, Agent, Card) :-
    agent_card:agent_card(Agent, User, Card).
