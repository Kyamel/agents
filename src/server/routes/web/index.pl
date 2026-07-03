:- module(app_index, [
    index_page/1
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module('../../views/page').
:- use_module('../../views/button_link').
:- use_module('../../views/ui').

:- http_handler(root(.), index_page, [method(get)]).

index_page(Request) :-
    ui:text_class(hero_title, 'mb-3', HeroTitleClass),
    button_link:button_link('/agents', 'Ver agentes', AgentsButton),
    button_link:button_link('/matches', 'Ver partidas', MatchesButton),
    info_card('/signup',
              '1. Crie sua conta',
              'Cadastre-se e verifique seu email para liberar o envio de agentes.', Step1),
    info_card('/agents/new',
              '2. Envie um agente',
              'Suba o código Prolog do seu detetive ou do seu ladrão.', Step2),
    info_card('/matches/new',
              '3. Crie partidas',
              'Coloque dois agentes para disputar e acompanhe o resultado.', Step3),
    button_link:button_link('/docs', 'Documentação da API', DocsButton),
    page:reply_page(Request, 'Scotland Yard', [
        section([class('mb-8')], [
            h1([class(HeroTitleClass)], 'Scotland Yard em Prolog'),
            p([class('text-surface-300 max-w-2xl')],
              'Plataforma para enviar agentes Prolog e colocá-los para disputar partidas de perseguição e dedução no estilo detetive e ladrão.')
        ]),
        div([class('flex flex-wrap gap-3 mb-10')], [AgentsButton, MatchesButton, DocsButton]),
        div([class('grid sm:grid-cols-3 gap-4')], [Step1, Step2, Step3])
    ]).

info_card(Href, Title, Text, Html) :-
    ui:surface_class('p-5 hover:border-surface-600 transition', CardClass),
    ui:link_class(LinkClass),
    ui:text_class(normal, 'text-surface-400', TextClass),
    Html = div([class(CardClass)], [
        h3([class('font-semibold mb-1')], [
            a([href(Href), class(LinkClass)], Title)
        ]),
        p([class(TextClass)], Text)
    ]).
