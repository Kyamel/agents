:- module(app_index, [
    index_page/1
  ]).

:- use_module(library(http/html_write)).
:- use_module('../../store').
:- use_module('../../components/page').


index_page(_Request) :-
    Title = 'Home',
    button_link('/agents', 'Ver agentes', AgentsButton),
    page:layout(Title, [
        h1([class('text-3xl font-bold mb-4')], 'Olá do Prolog!'),
        p([class('text-slate-300 mb-6')], 'Isso foi gerado com uma DSL HTML.'),
        AgentsButton
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

button_link(Href, Label, Html) :-
    Html = a(
        [
            href(Href),
            class('inline-block rounded-xl bg-blue-600 px-4 py-2 text-white font-semibold hover:bg-blue-500')
        ],
        Label
    ).

