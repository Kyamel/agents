:- module(page, [
    reply_page/3,
    reply_page/4,
    layout/3
]).

:- use_module(library(http/html_write)).
:- use_module('../http/web_session').
:- use_module(ui).

% Tema visual compartilhado pelo Tailwind e por componentes graficos em JS.
% Toda cor do app parte destas paletas; `reveal` e `map` apenas criam aliases
% semanticos. Isso evita hex duplicado entre classes e assets.
tailwind_config(
    "window.appTheme={\c
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
            emerald:{\c
                '200':'#a7f3d0',\c
                '300':'#6ee7b7',\c
                '400':'#34d399',\c
                '600':'#059669',\c
                '800':'#065f46',\c
                '900':'#064e3b',\c
                '950':'#022c22'\c
            },\c
            amber:{\c
                '200':'#fde68a',\c
                '300':'#fcd34d',\c
                '400':'#fbbf24',\c
                '800':'#92400e',\c
                '900':'#78350f',\c
                '950':'#451a03'\c
            },\c
            sky:{\c
                '200':'#bae6fd',\c
                '300':'#7dd3fc',\c
                '400':'#38bdf8',\c
                '800':'#075985',\c
                '900':'#0c4a6e',\c
                '950':'#082f49'\c
            },\c
            violet:{\c
                '200':'#ddd6fe',\c
                '300':'#c4b5fd',\c
                '400':'#a78bfa',\c
                '800':'#5b21b6',\c
                '900':'#4c1d95',\c
                '950':'#2e1065'\c
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
    };\c
    window.appTheme.colors.reveal={\c
        surface:window.appTheme.colors.violet['950'],\c
        border:window.appTheme.colors.violet['800'],\c
        text:window.appTheme.colors.violet['300']\c
    };\c
    window.appTheme.colors.map={\c
        thief:window.appTheme.colors.amber['400'],\c
        detective:window.appTheme.colors.sky['400'],\c
        edge:window.appTheme.colors.surface['700'],\c
        node:{\c
            fill:window.appTheme.colors.surface['800'],\c
            stroke:window.appTheme.colors.surface['500'],\c
            text:window.appTheme.colors.surface['200']\c
        },\c
        blocked:{\c
            fill:window.appTheme.colors.ufop['600'],\c
            stroke:window.appTheme.colors.ufop['200']\c
        },\c
        ready:{\c
            fill:window.appTheme.colors.emerald['600'],\c
            stroke:window.appTheme.colors.emerald['300']\c
        },\c
        robbery:{\c
            fill:window.appTheme.colors.amber['400'],\c
            stroke:window.appTheme.colors.amber['200']\c
        },\c
        inspection:{\c
            fill:window.appTheme.colors.sky['900'],\c
            stroke:window.appTheme.colors.sky['400']\c
        },\c
        contrast:window.appTheme.colors.surface['900']\c
    };\c
    tailwind.config={\c
        theme:{\c
            extend:{\c
                screens:{\c
                    'map-wide':'1440px'\c
                },\c
                colors:window.appTheme.colors\c
            }\c
        }\c
    }"
).

%!  reply_page(+Request, +Title, +Content) is det.
%
%   Renderiza uma pagina HTML completa: resolve a sessao, monta o layout com a
%   navegacao consciente de autenticacao e responde com Tailwind via CDN.
reply_page(Request, Title, Content) :-
    reply_page(Request, Title, Content, []).

%!  reply_page(+Request, +Title, +Content, +Options) is det.
%
%   Como reply_page/3, mas aceita Options. `width(wide)` alarga o container
%   principal (max-w-7xl) para paginas que aproveitam o espaco lateral no
%   desktop; o padrao continua max-w-4xl.
reply_page(Request, Title, Content, Options) :-
    web_session:current_user_or_anon(Request, User),
    layout(User, Content, Options, Body),
    tailwind_config(TwConfig),
    local_time_script(LocalTimeJs),
    reply_html_page(
        [ title(Title),
          meta([charset('UTF-8')]),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          script([src('https://cdn.tailwindcss.com')], []),
          script([], TwConfig),
          script([], LocalTimeJs)
          %script([src('https://unpkg.com/htmx.org@2.0.4')], [])
        ],
        Body
    ).

% Hook body//2 do reply_html_page: aplica a cor de fundo e o layout base no
% proprio elemento <body>, para o fundo cobrir toda a viewport (inclusive a
% area de overscroll). O conteudo chega meta-qualificado; strip_module o
% desembrulha antes de emitir.
body(_Style, Body0) -->
    { strip_module(Body0, _, Content) },
    html_root_attribute(lang, 'pt-BR'),
    html(body(class('min-h-screen bg-surface-950 text-surface-200 flex flex-col'),
              Content)).

% Converte todo <time class="js-localtime"> pro fuso horario local do cliente,
% usando o atributo datetime (ISO 8601 UTC vindo do servidor). Sem `<` nem `&`
% para nao sofrer escape de HTML. Ver ui:local_time/2 pra gerar os elementos.
local_time_script(
    "(function(){\c
        'use strict';\c
        function fmt(el){\c
            var iso=el.getAttribute('datetime');\c
            if(!iso){return;}\c
            var d=new Date(iso);\c
            if(isNaN(d.getTime())){return;}\c
            el.textContent=d.toLocaleString('pt-BR',{dateStyle:'medium',timeStyle:'short'});\c
            el.title=d.toString();\c
        }\c
        function run(){\c
            var els=document.querySelectorAll('time.js-localtime');\c
            for(var i=0;i!==els.length;i++){fmt(els[i]);}\c
        }\c
        if(document.readyState==='loading'){\c
            document.addEventListener('DOMContentLoaded',run);\c
        }else{run();}\c
    })();").

layout(User, Content, Body) :-
    layout(User, Content, [], Body).

layout(User, Content, Options, Body) :-
    nav(User, Nav),
    ufop_logo(Logo),
    main_width_class(Options, MainWidth),
    ui:text_class(normal, MainWidth, MainClass),
    footer_link('https://en.wikipedia.org/wiki/Scotland_Yard_(board_game)',
                'O Jogo', GameLink),
    footer_link('https://www.swi-prolog.org/', 'SWI-Prolog', PrologLink),
    footer_link('https://github.com/kyamel/agents', 'Código Fonte', GitLink),
    footer_link('https://icea.ufop.br/', 'ICEA', ICEALink),
    footer_link('https://ufop.br/', 'UFOP', UFOPLink),
    ui:text_class(meta, 'text-surface-300 font-medium', FooterTitleClass),
    ui:text_class(meta, 'mt-0.5', FooterLineClass),
    Body = [
        a([
            href('#conteudo-principal'),
            class('fixed left-4 top-2 z-50 -translate-y-16 rounded-lg \c
                   bg-ufop-600 px-4 py-2 font-semibold text-white \c
                   transition focus:translate-y-0 focus:outline-none \c
                   focus:ring-2 focus:ring-ufop-200')
        ], 'Pular para o conteúdo principal'),
        div([
            id('app-live-region'),
            class('sr-only'),
            role(status),
            'aria-live'(polite),
            'aria-atomic'(true)
        ], []),
        header([class('border-b border-surface-700')], [
                div([class('max-w-4xl mx-auto w-full p-4')], [Nav])
            ]),
            main([
                id('conteudo-principal'),
                tabindex(-1),
                class(MainClass)
            ], Content),
            footer([class('border-t border-surface-700')], [
                div([class('max-w-4xl mx-auto w-full p-6 flex flex-col sm:flex-row \c
                             items-center gap-4 text-surface-500')], [
                    Logo,
                    div([class('flex-1 text-center sm:text-left')], [
                        p([class(FooterTitleClass)], 'Scotland Yard em Prolog'),
                        p([class(FooterLineClass)], 'Disciplinas de Desenvolvimento Web e Linguagens de Programação'),
                        p([class(FooterLineClass)], [
                            'Desenvolvido na ',
                            UFOPLink,
                            ' / ',
                            ICEALink,
                            ' - 2026'
                        ]),
                        nav([
                            class('flex flex-wrap items-center justify-center sm:justify-start mt-0.5 gap-x-4 gap-y-1'),
                            'aria-label'('Links institucionais')
                        ], [
                            GameLink, PrologLink, GitLink
                        ])
                    ])
                ])
            ])
    ].

% `width(wide)` alarga so o main; header e footer seguem centralizados em
% max-w-4xl. Paginas wide centram o conteudo principal (ex.: o mapa) na mesma
% largura do header e usam a sobra lateral para conteudo extra.
main_width_class(Options, 'flex-1 max-w-[110rem] mx-auto w-full p-6') :-
    memberchk(width(wide), Options),
    !.
main_width_class(_Options, 'flex-1 max-w-4xl mx-auto w-full p-6').

ufop_logo(Html) :-
    ufop_logo_mark(Logo),
    Html = a([
        href('https://ufop.br'),
        target('_blank'),
        rel('noopener noreferrer'),
        'aria-label'('Ir para o site da UFOP (abre em nova aba)'),
        class('inline-flex items-center')
    ], Logo).

% Imagem da logo quando o arquivo existe; senao um fallback textual.
ufop_logo_mark(img([
        src('/assets/logo-ufop.png'),
        alt(''),
        class('h-32 w-auto shrink-0')
    ])) :-
    exists_file('assets/logo-ufop.png'),
    !.
ufop_logo_mark(span([class(Class)], 'UFOP')) :-
    ui:text_class(emphasis, 'text-ufop-500 shrink-0', Class).

footer_link(Href, Label, Html) :-
    ui:muted_link_class(Hover),
    ui:text_class(meta, Hover, Class),
    format(atom(AriaLabel), '~w (abre em nova aba)', [Label]),
    Html = a([ href(Href), target('_blank'), rel('noopener noreferrer'),
               class(Class), 'aria-label'(AriaLabel) ], Label).

% Barra de navegacao; os links variam conforme a sessao (anon vs logado).
nav(anon, Nav) :-
    !,
    ui:muted_link_class('font-bold mr-2', BrandHover),
    ui:text_class(normal, BrandHover, BrandClass),
    ui:text_class(meta, MetaClass),
    ui:link_class(MetaClass, NavClass),
    ui:muted_link_class('text-surface-300', EntrarHover),
    ui:text_class(meta, EntrarHover, EntrarClass),
    ui:primary_button_class(small, '', SignupButtonClass),
    ui:text_class(meta, SignupButtonClass, SignupClass),
    Nav = nav([
        class('flex flex-wrap items-center gap-x-4 gap-y-2'),
        'aria-label'('Navegação principal')
    ], [
        a([href('/'), class(BrandClass)], 'Scotland Yard'),
        a([href('/about'), class(NavClass)], 'Sobre'),
        a([href('/agents'), class(NavClass)], 'Agentes'),
        a([href('/matches'), class(NavClass)], 'Partidas'),
        div([class('ml-auto flex items-center gap-3')], [
            a([href('/login'), class(EntrarClass)], 'Entrar'),
            a([href('/signup'), class(SignupClass)], 'Criar conta')
        ])
    ]).
nav(User, Nav) :-
    format(atom(ProfileHref), '/users/~w', [User.id]),
    ui:muted_link_class('font-bold mr-2', BrandHover),
    ui:text_class(normal, BrandHover, BrandClass),
    ui:text_class(meta, MetaClass),
    ui:link_class(MetaClass, NavClass),
    ui:muted_link_class('text-surface-500 hidden sm:inline', ProfileHover),
    ui:text_class(meta, ProfileHover, ProfileClass),
    ui:text_class(meta, 'rounded-lg bg-surface-800 px-3 py-1.5 hover:bg-surface-700', SairClass),
    Nav = nav([
        class('flex flex-wrap items-center gap-x-4 gap-y-2'),
        'aria-label'('Navegação principal')
    ], [
        a([href('/'), class(BrandClass)], 'Scotland Yard'),
        a([href('/about'), class(NavClass)], 'Sobre'),
        a([href('/agents'), class(NavClass)], 'Agentes'),
        a([href('/matches'), class(NavClass)], 'Partidas'),
        %a([href('/agents/new'), class('text-surface-300 hover:text-white')], 'Enviar agente'),
        %a([href('/matches/new'), class('text-surface-300 hover:text-white')], 'Nova partida'),
        div([class('ml-auto flex items-center gap-3')], [
            a([href(ProfileHref), class(ProfileClass)], User.username),
            form([method(post), action('/logout')], [
                button([type(submit), class(SairClass)], 'Sair')
            ])
        ])
    ]).
