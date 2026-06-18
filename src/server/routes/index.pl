:- module(app_index, [
    index_page/1
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module('../../components/page').
:- use_module('../../components/button_link').
:- use_module('../../components/ui').

:- http_handler(root(.), index_page, [method(get)]).

index_page(Request) :-
    button_link:button_link('/agents', 'Ver agentes', AgentsButton),
    button_link:button_link('/matches', 'Ver partidas', MatchesButton),
    info_card('/signup',
              '1. Crie sua conta',
              'Cadastre-se e verifique seu email para liberar o envio de agentes.', Step1),
    info_card('/agents/new',
              '2. Envie um agente',
              'Suba o codigo Prolog do seu detetive ou do seu ladrão.', Step2),
    info_card('/matches/new',
              '3. Crie partidas',
              'Coloque dois agentes para disputar e acompanhe o resultado.', Step3),
    page:reply_page(Request, 'Scotland Yard', [
        section([class('mb-8')], [
            h1([class('text-3xl font-bold mb-3')], 'Scotland Yard em Prolog'),
            p([class('text-surface-300 max-w-2xl')],
              'Plataforma para enviar agentes Prolog e coloca-los para disputar partidas de perseguição e dedução no estilo detetive e ladrão.')
        ]),
        div([class('flex flex-wrap gap-3 mb-10')], [AgentsButton, MatchesButton]),
        div([class('grid sm:grid-cols-3 gap-4')], [Step1, Step2, Step3])
    ]).

info_card(Href, Title, Text, Html) :-
    ui:surface_class('p-5 hover:border-surface-600 transition', CardClass),
    ui:link_class(LinkClass),
    Html = div([class(CardClass)], [
        h3([class('font-semibold mb-1')], [
            a([href(Href), class(LinkClass)], Title)
        ]),
        p([class('text-surface-400 text-sm')], Text)
    ]).
