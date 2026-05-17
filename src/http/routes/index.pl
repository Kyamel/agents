:- module(app_index, [
    index_page/1
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../components/page').
:- use_module('../../components/button_link').

:- http_handler(root(.), index_page, [method(get)]).

%!  index_page(+Request) is det.
%
%   Renderiza a página inicial com links para agentes e partidas.
index_page(_Request) :-
    Title = 'Home',
    button_link:button_link('/agents', 'Ver agentes', AgentsButton),
    button_link:button_link('/matches', 'Ver partidas', MatchesButton),
    page:layout(Title, [
        h1([class('text-3xl font-bold mb-4')], 'Ola do Prolog!'),
        p([class('text-slate-300 mb-6')], 'Frontend e API servidos pelo mesmo backend.'),
        div([class('flex gap-3')], [AgentsButton, MatchesButton])
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
