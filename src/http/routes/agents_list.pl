:- module(route_agents_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/page').
:- use_module('../../components/agent_card').
:- use_module('../../components/button_link').
:- use_module('../../components/page_section').
:- use_module('../security/web_session').

:- http_handler(root(agents), handler, [method(get)]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:current_user_or_anon(Request, User),
    sqlite_store:list_agents(Agents),
    augment_with_owner(Agents, AgentsRich),
    render(Request, User, AgentsRich).

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
    sqlite_store:find_user_by_id(A.owner_user_id, Owner),
    !,
    Email = Owner.email.
owner_email(_, "").

% =============================
% Resposta (HTML)
% =============================

render(Request, User, Agents) :-
    agents_list_html(Agents, User, ListHtml),
    upload_cta(User, Cta),
    page_section:top_bar('Agentes', Cta, TopBar),
    page:reply_page(Request, 'Agentes', [
        TopBar,
        p([class('text-slate-400 mb-6')],
          'Agentes cadastrados na plataforma. Clique no nome do dono para ver o perfil.'),
        ListHtml
    ]).

upload_cta(anon, '') :- !.
upload_cta(_, Html) :-
    button_link:button_link('/agents/new', 'Enviar agente', Html).

agents_list_html([], _, Html) :-
    !,
    page_section:empty_state('Nenhum agente cadastrado ainda.', Html).
agents_list_html(Agents, User, div([class('grid sm:grid-cols-2 gap-4')], Cards)) :-
    maplist(card_for(User), Agents, Cards).

card_for(User, Agent, Card) :-
    agent_card:agent_card(Agent, User, Card).
