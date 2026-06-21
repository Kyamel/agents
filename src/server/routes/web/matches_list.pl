:- module(route_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../db/db').
:- use_module('../../views/page').
:- use_module('../../views/match_card').
:- use_module('../../views/button_link').
:- use_module('../../views/card_list').
:- use_module('../../views/pagination').
:- use_module('../../views/page_section').
:- use_module('../../http/web_session').

:- http_handler(root(matches), handler, [method(get)]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:current_user_or_anon(Request, User),
    http_parameters(Request, [page(Page0, [integer, default(1)])]),
    Page is max(1, Page0),
    db:list_matches_page(Page, 10, Matches, PaginationMeta),
    render(Request, User, Matches, PaginationMeta).

% =============================
% Resposta (HTML)
% =============================

render(Request, User, Matches, PaginationMeta) :-
    card_grid(Matches, match_card:match_card, 'grid sm:grid-cols-2 gap-4',
              'Nenhuma partida registrada ainda.', ListHtml),
    pagination:pagination_nav('/matches', PaginationMeta, Pagination),
    button_link:auth_button_link(User, '/matches/new', 'Nova partida', Cta),
    page_section:top_bar('Partidas', Cta, TopBar),
    page:reply_page(Request, 'Partidas', [
        TopBar,
        p([class('text-surface-400 mb-6')],
          'Histórico de partidas. Também disponivel em /api/v1/matches.'),
        ListHtml,
        Pagination
    ]).
