:- module(page, [
    reply_page/3,
    layout/3
]).

:- use_module(library(http/html_write)).
:- use_module('../http/web_session').
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

% Converte todo <time class="js-localtime"> pro fuso horario local do cliente,
% usando o atributo datetime (ISO 8601 UTC vindo do servidor). Sem `<` nem `&`
% para nao sofrer escape de HTML. Ver ui:local_time/2 pra gerar os elementos.
local_time_script(
    "(function(){\c
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
    nav(User, Nav),
    ufop_logo(Logo),
    ui:text_class(normal, 'flex-1 max-w-4xl mx-auto w-full p-6', MainClass),
    footer_link('https://en.wikipedia.org/wiki/Scotland_Yard_(board_game)',
                'O Jogo', GameLink),
    footer_link('https://www.swi-prolog.org/', 'SWI-Prolog', PrologLink),
    footer_link('https://github.com/kyamel/agents', 'Código Fonte', GitLink),
    footer_link('https://icea.ufop.br/', 'ICEA', ICEALink),
    footer_link('https://ufop.br/', 'UFOP', UFOPLink),
    ui:text_class(meta, 'text-surface-300 font-medium', FooterTitleClass),
    ui:text_class(meta, 'mt-0.5', FooterLineClass),
    Body = [
        div([class('min-h-screen bg-surface-950 text-surface-200 flex flex-col')], [
            header([class('border-b border-surface-800')], [
                div([class('max-w-4xl mx-auto w-full p-4')], [Nav])
            ]),
            main([class(MainClass)], Content),
            footer([class('border-t border-surface-800')], [
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
ufop_logo_mark(span([class(Class)], 'UFOP')) :-
    ui:text_class(emphasis, 'text-ufop-500 shrink-0', Class).

footer_link(Href, Label, Html) :-
    ui:muted_link_class(Hover),
    ui:text_class(meta, Hover, Class),
    Html = a([ href(Href), target('_blank'), rel('noopener noreferrer'),
               class(Class) ], Label).

% Barra de navegacao; os links variam conforme a sessao (anon vs logado).
nav(anon, Nav) :-
    !,
    ui:muted_link_class('font-bold mr-2', BrandHover),
    ui:text_class(normal, BrandHover, BrandClass),
    ui:text_class(meta, MetaClass),
    ui:link_class(MetaClass, NavClass),
    ui:muted_link_class('text-surface-300', EntrarHover),
    ui:text_class(meta, EntrarHover, EntrarClass),
    ui:primary_button_class('rounded-lg px-3 py-1.5', SignupButtonClass),
    ui:text_class(meta, SignupButtonClass, SignupClass),
    Nav = nav([class('flex flex-wrap items-center gap-x-4 gap-y-2')], [
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
    Nav = nav([class('flex flex-wrap items-center gap-x-4 gap-y-2')], [
        a([href('/'), class(BrandClass)], 'Scotland Yard'),
        a([href('/about'), class(NavClass)], 'Sobre'),
        a([href('/agents'), class(NavClass)], 'Agentes'),
        a([href('/matches'), class(NavClass)], 'Partidas'),
        %a([href('/agents/new'), class('text-surface-300 hover:text-white')], 'Enviar agente'),
        %a([href('/matches/new'), class('text-surface-300 hover:text-white')], 'Nova partida'),
        div([class('ml-auto flex items-center gap-3')], [
            a([href(ProfileHref), class(ProfileClass)], User.email),
            form([method(post), action('/logout')], [
                button([type(submit), class(SairClass)], 'Sair')
            ])
        ])
    ]).
