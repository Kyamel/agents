:- module(page, [
    reply_page/3,
    layout/3
]).

:- use_module(library(http/html_write)).
:- use_module('../http/security/web_session').

%!  tailwind_config(-Script) is det.
%
%   Configuracao do Tailwind (via CDN) que registra a paleta `ufop`, o
%   vermelho institucional da Universidade Federal de Ouro Preto.
tailwind_config(
    "tailwind.config={theme:{extend:{colors:{ufop:{\c
     '200':'#f0b3b8','400':'#db6a74','500':'#c5283a','600':'#a31621',\c
     '700':'#86121b','900':'#4d0a10','950':'#310608'}}}}}"
).

%!  reply_page(+Request, +Title, +Content) is det.
%
%   Renderiza uma pagina HTML completa: resolve a sessao atual, monta o layout
%   com navegacao consciente de autenticacao e responde com Tailwind via CDN.
reply_page(Request, Title, Content) :-
    web_session:current_user_or_anon(Request, User),
    layout(User, Content, Body),
    tailwind_config(TwConfig),
    reply_html_page(
        [ title(Title),
          meta([charset('UTF-8')]),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          script([src('https://cdn.tailwindcss.com')], []),
          script([], TwConfig),
          script([src('https://unpkg.com/htmx.org@2.0.4')], [])
        ],
        Body
    ).

%!  layout(+User, +Content, -Body) is det.
%
%   Monta o layout base (cabecalho, conteudo e rodape) da aplicacao.
layout(User, Content, Body) :-
    nav(User, Nav),
    ufop_logo(Logo),
    footer_link('https://en.wikipedia.org/wiki/Scotland_Yard_(board_game)',
                'O Jogo', GameLink),
    footer_link('https://www.swi-prolog.org/', 'SWI-Prolog', PrologLink),
    footer_link('https://github.com/kyamel/agents', 'Código Fonte', GitLink),
    footer_link('https://icea.ufop.br/', 'ICEA', ICEALink),
    footer_link('https://ufop.br/', 'UFOP', UFOPLink),
    Body = [
        div([class('min-h-screen bg-slate-950 text-slate-200 flex flex-col')], [
            header([class('border-b border-slate-800')], [
                div([class('max-w-4xl mx-auto w-full p-4')], [Nav])
            ]),
            main([class('flex-1 max-w-4xl mx-auto w-full p-6')], Content),
            footer([class('border-t border-slate-800')], [
                div([class('max-w-4xl mx-auto w-full p-6 flex flex-col sm:flex-row \c
                             items-center gap-4 text-sm text-slate-500')], [
                    Logo,
                    div([class('flex-1 text-center sm:text-left')], [
                        p([class('text-slate-300 font-medium')], 'Scotland Yard em Prolog'),
                        p([class('mt-0.5')], 'Disciplinas de Desenvolvimento Web e Linguagens de Programação'),
                        p([class('mt-0.5')], [
                            'Desenvolvido na ',
                            UFOPLink,
                            ' / ',
                            ICEALink,
                            ' - 2026'
                        ]),
                        nav([class('flex flex-wrap items-center justify-center sm:justify-start mt-0.5 gap-x-4 gap-y-1')], [
                            GameLink, PrologLink, GitLink
                        ])
                    ])
                ])
            ])
        ])
    ].

%!  ufop_logo(-Html) is det.
%
%   Logo da UFOP no rodape. Usa a imagem em `assets/logo-ufop.png` quando ela
%   existe; caso contrario, exibe um fallback textual.
ufop_logo(Html) :-
    ufop_logo_mark(Logo),
    Html = a([
        href('https://ufop.br'),
        target('_blank'),
        rel('noopener noreferrer'),
        'aria-label'('Ir para o site da UFOP'),
        class('inline-flex items-center')
    ], Logo).

%!  ufop_logo_mark(-Logo) is det.
%
%   A imagem da logo quando o arquivo existe; senao um fallback textual.
ufop_logo_mark(img([
        src('/assets/logo-ufop.png'),
        alt('UFOP'),
        class('h-32 w-auto shrink-0')
    ])) :-
    exists_file('assets/logo-ufop.png'),
    !.
ufop_logo_mark(span([
        class('text-ufop-500 font-bold text-lg shrink-0')
    ], 'UFOP')).

%!  footer_link(+Href, +Label, -Html) is det.
%
%   Link externo do rodape, aberto em nova aba.
footer_link(Href, Label, Html) :-
    Html = a([ href(Href), target('_blank'), rel('noopener noreferrer'),
               class('hover:text-ufop-400 transition underline underline-offset-2') ], Label).

%!  nav(+User, -Nav) is det.
%
%   Monta a barra de navegacao, variando os links conforme a sessao.
nav(anon, Nav) :-
    !,
    Nav = nav([class('flex flex-wrap items-center gap-x-4 gap-y-2 text-sm')], [
        a([href('/'), class('font-bold text-base mr-2')], 'Scotland Yard'),
        a([href('/agents'), class('text-slate-300 hover:text-white')], 'Agentes'),
        a([href('/matches'), class('text-slate-300 hover:text-white')], 'Partidas'),
        div([class('ml-auto flex items-center gap-3')], [
            a([href('/login'), class('text-slate-300 hover:text-white')], 'Entrar'),
            a([href('/signup'),
               class('rounded-lg bg-ufop-600 px-3 py-1.5 font-semibold hover:bg-ufop-500')],
              'Criar conta')
        ])
    ]).
nav(User, Nav) :-
    Nav = nav([class('flex flex-wrap items-center gap-x-4 gap-y-2 text-sm')], [
        a([href('/'), class('font-bold text-base mr-2')], 'Scotland Yard'),
        a([href('/agents'), class('text-slate-300 hover:text-white')], 'Agentes'),
        a([href('/matches'), class('text-slate-300 hover:text-white')], 'Partidas'),
        a([href('/agents/new'), class('text-slate-300 hover:text-white')], 'Enviar agente'),
        a([href('/matches/new'), class('text-slate-300 hover:text-white')], 'Nova partida'),
        div([class('ml-auto flex items-center gap-3')], [
            span([class('text-slate-500 hidden sm:inline')], User.email),
            form([method(post), action('/logout')], [
                button([type(submit),
                        class('rounded-lg bg-slate-800 px-3 py-1.5 hover:bg-slate-700')],
                       'Sair')
            ])
        ])
    ]).
