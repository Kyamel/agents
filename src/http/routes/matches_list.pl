:- module(route_matches_list, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/layout/page').
:- use_module('../../components/cards/match_card').
:- use_module('../../components/ui/button_link').
:- use_module('../../components/ui/page_section').
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
    matches_list_html(Matches, ListHtml),
    new_match_cta(User, Cta),
    page_section:top_bar('Partidas', Cta, TopBar),
    page:reply_page(Request, 'Partidas', [
        TopBar,
        p([class('text-slate-400 mb-6')],
          'Historico de partidas. Tambem disponivel na API em /api/v1/matches.'),
        ListHtml
    ]).

new_match_cta(anon, '') :- !.
new_match_cta(_, Html) :-
    button_link:button_link('/matches/new', 'Nova partida', Html).

matches_list_html([], Html) :-
    !,
    page_section:empty_state('Nenhuma partida registrada ainda.', Html).
matches_list_html(Matches, div([class('grid gap-4')], Cards)) :-
    maplist(match_card:match_card, Matches, Cards).
