:- module(app_matches, [
    matches_page/1
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/page').

:- http_handler(root(matches), matches_page, [method(get)]).

%!  matches_page(+Request) is det.
%
%   Renderiza a página com histórico de partidas.
matches_page(_Request) :-
    Title = 'Matches',
    sqlite_store:list_matches(Matches),
    matches_list(Matches, MatchesHtml),
    page:layout(Title, [
        h1([class('text-2xl font-bold mb-4')], 'Partidas'),
        p([class('text-slate-400 mb-6')],
          'Historico de partidas criadas via API em /api/v1/matches.'),
        MatchesHtml
      ],
      Page
    ),
    reply_html_page(
        [
            title(Title),
            script([src('https://cdn.tailwindcss.com')], [])
        ],
        Page
    ).

%!  matches_list(+Matches, -Html) is det.
%
%   Converte a lista de partidas em estrutura HTML.
matches_list(Matches, Html) :-
    (   Matches == []
    ->  Html = p([class('text-slate-500')], 'Nenhuma partida registrada ainda.')
    ;   maplist(match_card, Matches, Cards),
        Html = div([class('grid gap-4')], Cards)
    ).

%!  match_card(+Match, -Html) is det.
%
%   Renderiza o cartão HTML de uma partida.
match_card(Match, Html) :-
    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        h2([class('font-bold text-lg')], Match.id),
        p([class('text-slate-300')], ['Vencedor: ', Match.winner]),
        p([class('text-slate-500 text-sm mt-2')], ['Thief: ', Match.thief_agent_id]),
        p([class('text-slate-500 text-sm')], ['Detective: ', Match.detective_agent_id]),
        p([class('text-slate-500 text-sm')], ['Criada em: ', Match.created_at])
    ]).
