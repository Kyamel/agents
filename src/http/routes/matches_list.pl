:- module(route_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/page').
:- use_module('../../components/match_card').
:- use_module('../../components/button_link').
:- use_module('../../components/card_list').
:- use_module('../../components/page_section').
:- use_module('../security/web_session').

:- http_handler(root(matches), handler, [method(get)]).

% =============================
% Handler
% =============================

handler(Request) :-
    web_session:current_user_or_anon(Request, User),
    sqlite_store:list_matches(Matches),
    render(Request, User, Matches).

% =============================
% Resposta (HTML)
% =============================

render(Request, User, Matches) :-
    card_grid(Matches, match_card:match_card, 'grid gap-4',
              'Nenhuma partida registrada ainda.', ListHtml),
    button_link:auth_button_link(User, '/matches/new', 'Nova partida', Cta),
    page_section:top_bar('Partidas', Cta, TopBar),
    page:reply_page(Request, 'Partidas', [
        TopBar,
        p([class('text-slate-400 mb-6')],
          'Historico de partidas. Tambem disponivel na API em /api/v1/matches.'),
        ListHtml
    ]).
