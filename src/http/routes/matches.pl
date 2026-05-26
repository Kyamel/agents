:- module(route_matches, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/layout/page').
:- use_module('../../components/cards/match_card').
:- use_module('../../components/ui/button_link').
:- use_module('../security/web_session').
:- use_module('./matches/new', []).
:- use_module('./matches/[id]', []).

:- http_handler(root(matches), router, [prefix]).

% Dispatcher do segmento /matches. O proprio arquivo renderiza o index;
% rotas mais especificas delegam para arquivos irmaos no subdir matches/.
router(Request) :-
    memberchk(path(Path), Request),
    dispatch(Path, Request).

dispatch('/matches', Request)   :- !, render_index(Request).
dispatch('/matches/', Request)  :- !, render_index(Request).
dispatch('/matches/new', Request) :-
    !,
    memberchk(method(Method), Request),
    route_matches_new:render(Method, Request).
dispatch(Path, Request) :-
    atom_concat('/matches/', Id, Path),
    Id \== '',
    !,
    route_matches_show:render(Request, Id).
dispatch(_, Request) :-
    route_matches_show:render_invalid(Request).

% -----------------------------
% Index: /matches
% -----------------------------

render_index(Request) :-
    web_session:current_user_or_anon(Request, User),
    sqlite_store:list_matches(Matches),
    matches_list_html(Matches, ListHtml),
    new_match_cta(User, Cta),
    page:reply_page(Request, 'Partidas', [
        div([class('flex items-center justify-between gap-3 mb-2')], [
            h1([class('text-2xl font-bold')], 'Partidas'),
            Cta
        ]),
        p([class('text-slate-400 mb-6')],
          'Historico de partidas. Tambem disponivel na API em /api/v1/matches.'),
        ListHtml
    ]).

new_match_cta(anon, '') :- !.
new_match_cta(_, Html) :-
    button_link:button_link('/matches/new', 'Nova partida', Html).

matches_list_html([], Html) :-
    !,
    Html = p([class('text-slate-500')], 'Nenhuma partida registrada ainda.').
matches_list_html(Matches, div([class('grid gap-4')], Cards)) :-
    maplist(match_card:match_card, Matches, Cards).
