:- module(page, [
    reply_page/3,
    layout/3
]).

:- use_module(library(http/html_write)).
:- use_module('../server/security/web_session').
:- use_module(ui).

% Paleta do Tailwind (CDN). `ufop` e o vermelho institucional da UFOP.
% `surface` e a escala neutra do app: centralizar aqui permite
% re-tematizar o tom neutro inteiro mudando so estes hex. Usar sempre
% bg-surface-*/text-surface-*/border-surface-* (nunca cores cruas do Tailwind).
tailwind_config(
    "tailwind.config={\c
        theme:{\c
            extend:{\c
                colors:{\c
                    ufop:{\c
                        '200':'#f0b3b8',\c
                        '400':'#db6a74',\c
                        '500':'#c5283a',\c
                        '600':'#a31621',\c
                        '700':'#86121b',\c
                        '900':'#4d0a10',\c
                        '950':'#310608'\c
                    },\c
                    surface:{\c
                        '100':'#f1f5f9',\c
                        '200':'#e2e8f0',\c
                        '300':'#cbd5e1',\c
                        '400':'#94a3b8',\c
                        '500':'#64748b',\c
                        '600':'#475569',\c
                        '700':'#334155',\c
                        '800':'#1e293b',\c
                        '900':'#0f172a',\c
                        '950':'#020617'\c
                    }\c
                }\c
            }\c
        }\c
    }"
).

%!  reply_page(+Request, +Title, +Content) is det.
%
%   Renderiza uma pagina HTML completa: resolve a sessao, monta o layout com a
%   navegacao consciente de autenticacao e responde com Tailwind via CDN.
reply_page(Request, Title, Content) :-
    web_session:current_user_or_anon(Request, User),
    layout(User, Content, Body),
    tailwind_config(TwConfig),
    reply_html_page(
        [ title(Title),
          meta([charset('UTF-8')]),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          script([src('https://cdn.tailwindcss.com')], []),
          script([], TwConfig)
          %script([src('https://unpkg.com/htmx.org@2.0.4')], [])
        ],
        Body
    ).

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
        div([class('min-h-screen bg-surface-950 text-surface-200 flex flex-col')], [
            header([class('border-b border-surface-800')], [
                div([class('max-w-4xl mx-auto w-full p-4')], [Nav])
            ]),
            main([class('flex-1 max-w-4xl mx-auto w-full p-6')], Content),
            footer([class('border-t border-surface-800')], [
                div([class('max-w-4xl mx-auto w-full p-6 flex flex-col sm:flex-row \c
                             items-center gap-4 text-sm text-surface-500')], [
                    Logo,
                    div([class('flex-1 text-center sm:text-left')], [
                        p([class('text-surface-300 font-medium')], 'Scotland Yard em Prolog'),
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

ufop_logo(Html) :-
    ufop_logo_mark(Logo),
    Html = a([
        href('https://ufop.br'),
        target('_blank'),
        rel('noopener noreferrer'),
        'aria-label'('Ir para o site da UFOP'),
        class('inline-flex items-center')
    ], Logo).

% Imagem da logo quando o arquivo existe; senao um fallback textual.
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

footer_link(Href, Label, Html) :-
    Html = a([ href(Href), target('_blank'), rel('noopener noreferrer'),
               class('hover:text-ufop-400 transition underline underline-offset-2') ], Label).

% Barra de navegacao; os links variam conforme a sessao (anon vs logado).
nav(anon, Nav) :-
    !,
    ui:link_class(NavClass),
    Nav = nav([class('flex flex-wrap items-center gap-x-4 gap-y-2 text-sm')], [
        a([href('/'), class('font-bold text-base mr-2 hover:underline underline-offset-2')], 'Scotland Yard'),
        a([href('/agents'), class(NavClass)], 'Agentes'),
        a([href('/matches'), class(NavClass)], 'Partidas'),
        div([class('ml-auto flex items-center gap-3')], [
            a([href('/login'), class('text-surface-300 hover:text-white')], 'Entrar'),
            a([href('/signup'),
               class('rounded-lg bg-ufop-600 px-3 py-1.5 font-semibold hover:bg-ufop-500')],
              'Criar conta')
        ])
    ]).
nav(User, Nav) :-
    format(atom(ProfileHref), '/users/~w', [User.id]),
    ui:link_class(NavClass),
    Nav = nav([class('flex flex-wrap items-center gap-x-4 gap-y-2 text-sm')], [
        a([href('/'), class('font-bold text-base mr-2 hover:underline underline-offset-2')], 'Scotland Yard'),
        a([href('/agents'), class(NavClass)], 'Agentes'),
        a([href('/matches'), class(NavClass)], 'Partidas'),
        %a([href('/agents/new'), class('text-surface-300 hover:text-white')], 'Enviar agente'),
        %a([href('/matches/new'), class('text-surface-300 hover:text-white')], 'Nova partida'),
        div([class('ml-auto flex items-center gap-3')], [
            a([href(ProfileHref),
               class('text-surface-500 hidden sm:inline hover:underline underline-offset-2')],
              User.email),
            form([method(post), action('/logout')], [
                button([type(submit),
                        class('rounded-lg bg-surface-800 px-3 py-1.5 hover:bg-surface-700')],
                       'Sair')
            ])
        ])
    ]).
