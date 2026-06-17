:- module(route_agents_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module('../../db/db').
:- use_module('../../components/page').
:- use_module('../../components/agent_card').
:- use_module('../../components/button_link').
:- use_module('../../components/card_list').
:- use_module('../../components/pagination').
:- use_module('../../components/page_section').
:- use_module('../security/web_session').

:- http_handler(root(agents), handler, [method(get)]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:current_user_or_anon(Request, User),
    http_parameters(Request, [page(Page, [integer, default(1)])]),
    db:list_agents(Agents),
    augment_with_owner(Agents, AgentsRich),
    pagination:paginate(AgentsRich, 20, Page, PageAgents, PageMeta),
    render(Request, User, PageAgents, PageMeta).

% =============================
% Logica (DB enrichment)
% =============================

% N+1 query consciente: volumes pequenos no projeto.
augment_with_owner([], []).
augment_with_owner([A|As], [A2|As2]) :-
    owner_email(A, Email),
    put_dict(owner_email, A, Email, A2),
    augment_with_owner(As, As2).

owner_email(A, Email) :-
    db:find_user_by_id(A.owner_user_id, Owner),
    !,
    Email = Owner.email.
owner_email(_, "").

% =============================
% Resposta (HTML)
% =============================

render(Request, User, Agents, PageMeta) :-
    card_grid(Agents, render_card(User), 'grid sm:grid-cols-2 gap-4',
              'Nenhum agente cadastrado ainda.', ListHtml),
    pagination:pagination_nav('/agents', PageMeta, Pagination),
    button_link:auth_button_link(User, '/agents/new', 'Enviar agente', Cta),
    page_section:top_bar('Agentes', Cta, TopBar),
    page:reply_page(Request, 'Agentes', [
        TopBar,
        p([class('text-slate-400 mb-6')],
          'Agentes cadastrados na plataforma. Também disponivel em /api/v1/agents.'),
        ListHtml,
        Pagination
    ]).

render_card(User, Agent, Card) :-
    agent_card:agent_card(Agent, User, Card).
