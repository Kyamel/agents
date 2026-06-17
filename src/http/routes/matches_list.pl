:- module(route_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module('../../db/db').
:- use_module('../../components/page').
:- use_module('../../components/match_card').
:- use_module('../../components/button_link').
:- use_module('../../components/card_list').
:- use_module('../../components/pagination').
:- use_module('../../components/page_section').
:- use_module('../security/web_session').

:- http_handler(root(matches), handler, [method(get)]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:current_user_or_anon(Request, User),
    http_parameters(Request, [page(Page, [integer, default(1)])]),
    db:list_matches(Matches),
    pagination:paginate(Matches, 20, Page, PageMatches, PageMeta),
    render(Request, User, PageMatches, PageMeta).

% =============================
% Resposta (HTML)
% =============================

render(Request, User, Matches, PageMeta) :-
    card_grid(Matches, match_card:match_card, 'grid sm:grid-cols-2 gap-4',
              'Nenhuma partida registrada ainda.', ListHtml),
    pagination:pagination_nav('/matches', PageMeta, Pagination),
    button_link:auth_button_link(User, '/matches/new', 'Nova partida', Cta),
    page_section:top_bar('Partidas', Cta, TopBar),
    page:reply_page(Request, 'Partidas', [
        TopBar,
        p([class('text-slate-400 mb-6')],
          'Histórico de partidas. Também disponivel em /api/v1/matches.'),
        ListHtml,
        Pagination
    ]).
