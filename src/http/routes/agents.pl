:- module(route_agents, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/layout/page').
:- use_module('../../components/cards/agent_card').
:- use_module('../../components/ui/button_link').
:- use_module('../security/web_session').
:- use_module('./agents/new', []).
:- use_module('./agents/[id]', []).

:- http_handler(root(agents), router, [prefix]).

% Dispatcher do segmento /agents. Este arquivo cuida do index; rotas mais
% especificas delegam para arquivos irmaos no subdir agents/.
router(Request) :-
    memberchk(path(Path), Request),
    memberchk(method(Method), Request),
    dispatch(Path, Method, Request).

dispatch('/agents', get, Request)   :- !, render_index(Request).
dispatch('/agents/', get, Request)  :- !, render_index(Request).
dispatch('/agents/new', Method, Request) :-
    !,
    route_agents_new:render(Method, Request).
dispatch(Path, delete, Request) :-
    atom_concat('/agents/', Id, Path),
    Id \== '',
    Id \== new,
    !,
    route_agents_resource:handle(Request, Id).
dispatch(_, _, Request) :-
    render_index(Request).

% -----------------------------
% Index: /agents
% -----------------------------

render_index(Request) :-
    web_session:current_user_or_anon(Request, User),
    sqlite_store:list_agents(Agents),
    augment_with_owner(Agents, AgentsRich),
    agents_list_html(AgentsRich, User, ListHtml),
    upload_cta(User, Cta),
    page:reply_page(Request, 'Agentes', [
        div([class('flex items-center justify-between gap-3 mb-2')], [
            h1([class('text-2xl font-bold')], 'Agentes'),
            Cta
        ]),
        p([class('text-slate-400 mb-6')],
          'Agentes cadastrados na plataforma. Clique no nome do dono para ver o perfil.'),
        ListHtml
    ]).

upload_cta(anon, '') :- !.
upload_cta(_, Html) :-
    button_link:button_link('/agents/new', 'Enviar agente', Html).

agents_list_html([], _, Html) :-
    !,
    Html = p([class('text-slate-500')], 'Nenhum agente cadastrado ainda.').
agents_list_html(Agents, User, div([class('grid sm:grid-cols-2 gap-4')], Cards)) :-
    maplist(card_for(User), Agents, Cards).

card_for(User, Agent, Card) :-
    agent_card:agent_card(Agent, User, Card).

% Insere `owner_email` em cada agent dict (N+1 query consciente; volumes
% pequenos no projeto).
augment_with_owner([], []).
augment_with_owner([A|As], [A2|As2]) :-
    (   sqlite_store:find_user_by_id(A.owner_user_id, Owner)
    ->  put_dict(owner_email, A, Owner.email, A2)
    ;   put_dict(owner_email, A, "", A2)
    ),
    augment_with_owner(As, As2).
