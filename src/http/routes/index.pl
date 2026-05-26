:- module(app_index, [
    index_page/1
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module('../../components/layout/page').
:- use_module('../../components/ui/button_link').

:- http_handler(root(.), index_page, [method(get)]).

%!  index_page(+Request) is det.
%
%   Renderiza a pagina inicial, apresentando a plataforma e os primeiros passos.
index_page(Request) :-
    button_link:button_link('/agents', 'Ver agentes', AgentsButton),
    button_link:button_link('/matches', 'Ver partidas', MatchesButton),
    info_card('1. Crie sua conta',
              'Cadastre-se e verifique seu email para liberar o envio de agentes.', Step1),
    info_card('2. Envie um agente',
              'Suba o codigo Prolog do seu detetive ou do seu ladrao.', Step2),
    info_card('3. Crie partidas',
              'Coloque dois agentes para disputar e acompanhe o resultado.', Step3),
    page:reply_page(Request, 'Scotland Yard', [
        section([class('mb-8')], [
            h1([class('text-3xl font-bold mb-3')], 'Scotland Yard em Prolog'),
            p([class('text-slate-300 max-w-2xl')],
              'Plataforma para enviar agentes Prolog e coloca-los para disputar partidas de perseguição e dedução no estilo detetive e ladrão.')
        ]),
        div([class('flex flex-wrap gap-3 mb-10')], [AgentsButton, MatchesButton]),
        div([class('grid sm:grid-cols-3 gap-4')], [Step1, Step2, Step3])
    ]).

%!  info_card(+Title, +Text, -Html) is det.
%
%   Cartao informativo usado na secao de primeiros passos.
info_card(Title, Text, Html) :-
    Html = div([class('rounded-xl bg-slate-900 p-5 border border-slate-800')], [
        h3([class('font-semibold mb-1')], Title),
        p([class('text-slate-400 text-sm')], Text)
    ]).
