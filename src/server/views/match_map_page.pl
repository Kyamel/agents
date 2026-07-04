:- module(match_map_page, [
    content/6
]).

:- use_module(page_section).
:- use_module(ui).

%!  content(+MapName, +ThiefName, +DetectiveName, +DetailLink, +DataJson,
%!          -Content) is det.
%
%   Componentes declarativos da pagina do mapa. O JSON contem frames prontos;
%   os templates sao clonados pelo controlador durante o playback.
content(MapName, ThiefName, DetectiveName, DetailLink, DataJson, Content) :-
    page_section:back_link(DetailLink, 'Voltar para a partida', BackLink),
    map_controls(Controls),
    map_legend(Legend),
    map_event_card(EventInfo),
    map_scroll_card(
        amber,
        [
            'Aparência do ladrão',
            span([
                id('mm-thief-identity'),
                class('hidden normal-case tracking-normal rounded-full \c
                       bg-amber-950 border border-amber-800 px-2.5 py-1 \c
                       font-mono font-semibold text-amber-300')
            ], [])
        ],
        'mm-appearance',
        'space-y-2 overflow-y-auto min-h-0 flex-1 pr-1',
        AppearanceCard
    ),
    map_scroll_card(
        emerald,
        'Itens coletados',
        'mm-collected',
        'flex flex-wrap content-start gap-2 overflow-y-auto min-h-0 flex-1 pr-1',
        CollectedCard
    ),
    map_state_card(
        sky,
        'Mandato do detetive',
        'mm-mandate',
        MandateCard
    ),
    map_replay_layout(AppearanceCard, CollectedCard, ReplayLayout),
    map_templates(Templates),
    ui:text_class(title, 'mt-3 mb-1', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-5', DescriptionClass),
    Content = [
        BackLink,
        h1([class(TitleClass)], 'Mapa da partida'),
        p([class(DescriptionClass)], [
            'Mapa: ', b([], MapName),
            '  •  Ladrão: ', b([], ThiefName),
            '  •  Detetive: ', b([], DetectiveName)
        ]),
        Legend,
        Controls,
        ReplayLayout,
        div([class('grid gap-4 mb-4 lg:grid-cols-[minmax(0,_5fr)_minmax(0,_3fr)] \c
                    lg:items-stretch')], [
            EventInfo, MandateCard
        ]),
        Templates,
        script([type('application/json'), id('match-map-data')], DataJson),
        script([
            type(module),
            src('/assets/match_map.js?v=23')
        ], [])
    ].

map_controls(Html) :-
    ui:surface_class('p-4 mb-4 flex flex-wrap items-center gap-3', CardClass),
    ui:text_class(meta,
                  'font-mono text-surface-300 min-w-[5rem] text-center',
                  TurnClass),
    ui:text_class(meta,
                  'text-surface-400 flex items-center gap-2 ml-auto',
                  IntervalClass),
    ui:primary_button_class(
        'inline-flex h-10 w-10 shrink-0 items-center justify-center \c
         rounded-lg p-0 font-mono text-xl leading-none',
        PlayClass
    ),
    Html = div([class(CardClass)], [
        button([type(button), id('mm-play'), class(PlayClass),
                'aria-label'('Reproduzir'), title('Reproduzir')], [
            span([id('mm-play-icon'), 'aria-hidden'(true),
                  class('block'), style('transform: translateY(-1px)')], '▶︎')
        ]),
        input([type(range), id('mm-slider'), min(0), max(0), value(0), step(1),
               class('flex-1 accent-ufop-500')]),
        span([id('mm-turn-label'), class(TurnClass)], 'Início'),
        label([class(IntervalClass)], [
            'Intervalo',
            input([type(number), id('mm-interval'), value(500), min(100),
                   step(100),
                   class('w-24 rounded-lg bg-surface-800 border border-surface-600 \c
                          px-2 py-1 text-surface-200')]),
            'ms'
        ])
    ]).

% `map-wide` fica definido na configuracao global do Tailwind (page.pl).
map_replay_layout(AppearanceCard, CollectedCard, Html) :-
    ui:surface_class(
        'overflow-hidden order-first lg:order-none',
        GraphClass
    ),
    Html = div([class('grid gap-4 mb-4 lg:items-start \c
                       lg:grid-cols-[minmax(16rem,_20rem)_minmax(0,_1fr)] \c
                       xl:grid-cols-[minmax(0,_1fr)_56rem] \c
                       map-wide:grid-cols-[minmax(0,_1fr)_56rem_minmax(0,_1fr)]')], [
        AppearanceCard,
        div([id('mm-graph'), class(GraphClass)], []),
        div([class('min-w-0 lg:col-span-2 map-wide:col-span-1')],
            [CollectedCard])
    ]).

map_legend(Html) :-
    ui:text_class(
        meta,
        'grid grid-cols-2 gap-x-3 gap-y-2 mb-4 \c
         sm:flex sm:flex-wrap sm:items-center sm:gap-x-5 sm:gap-y-2',
        Class
    ),
    legend_item('rounded-full bg-map-thief', 'Rota do ladrão', Thief),
    legend_item('rounded-full bg-map-detective', 'Rota do detetive', Detective),
    legend_item('rounded bg-map-blocked-fill', 'Cidade bloqueada', Blocked),
    legend_item('rounded bg-map-ready-fill', 'Objetivo liberado', Ready),
    legend_item('rounded bg-map-robbery-fill', 'Evento de furto', Robbery),
    legend_item('rounded bg-map-inspection-fill', 'Cidade inspecionada', Inspection),
    legend_glyph('💎', 'Tesouro na cidade', Treasure),
    legend_glyph('🔑', 'Item na cidade', Item),
    Html = div([class(Class)], [
        Thief, Detective, Blocked, Ready, Robbery, Inspection, Treasure, Item
    ]).

legend_item(ColorClass, Label,
            span([class('min-w-0 flex items-center gap-2 leading-tight')], [
                span([class(Class)], []),
                Label
            ])) :-
    atomic_list_concat(
        ['inline-block shrink-0 w-3 h-3', ColorClass],
        ' ',
        Class
    ).

legend_glyph(Glyph, Label,
             span([class('min-w-0 flex items-center gap-2 leading-tight')], [
                 span([class('shrink-0')], Glyph),
                 Label
             ])).

map_event_card(Html) :-
    ui:surface_class('overflow-hidden', CardClass),
    ui:eyebrow_class(amber, AccentClass),
    atomic_list_concat([AccentClass, 'px-4 pt-4 pb-2'], ' ', HeadingClass),
    event_side('Ladrão', thief, ThiefSide),
    event_side('Detetive', detective, DetectiveSide),
    Html = div([class(CardClass)], [
        p([class(HeadingClass)], 'Evento'),
        div([
            id('mm-event'),
            class('grid grid-cols-2 divide-x divide-surface-700')
        ], [
            ThiefSide,
            DetectiveSide
        ])
    ]).

event_side(Label, Agent, Html) :-
    ui:eyebrow_class(slate, LabelClass),
    Html = div([class('min-w-0 px-3 pb-3 pt-1')], [
        p([class(LabelClass)], Label),
        div([
            class('mt-2 space-y-2'),
            'data-event-agent'(Agent)
        ], [])
    ]).

map_scroll_card(Accent, Label, Id, ContentClass, Html) :-
    ui:eyebrow_class(Accent, AccentClass),
    ui:surface_class('p-4 flex flex-col overflow-hidden js-map-height', CardClass),
    atomic_list_concat(
        [AccentClass, 'mb-3 shrink-0 flex flex-wrap items-center gap-2'],
        ' ',
        HeadingClass
    ),
    Html = div([class(CardClass)], [
        p([class(HeadingClass)], Label),
        div([id(Id), class(ContentClass)], [])
    ]).

map_state_card(Accent, Label, Id, Html) :-
    ui:eyebrow_class(Accent, AccentClass),
    ui:surface_class('p-4', CardClass),
    atomic_list_concat([AccentClass, 'mb-3'], ' ', HeadingClass),
    Html = div([class(CardClass)], [
        p([class(HeadingClass)], Label),
        div([id(Id), class('space-y-2')], [])
    ]).

map_templates(Html) :-
    state_label_class(LabelClass),
    Html = div([class('hidden'), 'aria-hidden'(true)], [
        % Classes aplicadas dinamicamente aos clones; mantidas no HTML para o
        % compilador Tailwind CDN gerar todos os estados antes do playback.
        span([class('border-reveal-border bg-reveal-surface/40 \c
                     bg-reveal-surface text-reveal-text border-sky-800 \c
                     bg-sky-950/40 bg-sky-950 text-sky-200 text-sky-300 \c
                     border-amber-800 border-amber-900/60 bg-amber-950/40 \c
                     text-amber-200 text-amber-300 border-emerald-800 \c
                     bg-emerald-950/40 text-emerald-200 text-emerald-300 \c
                     border-surface-700 bg-surface-950 text-rose-300 \c
                     text-surface-300')], []),
        template([id('mm-template-empty')], [
            p([
                class('text-surface-500 italic'),
                'data-role'(message)
            ], [])
        ]),
        template([id('mm-template-turn-event')], [
            div([
                class('rounded-lg border px-3 py-2')
            ], [
                p([
                    class('font-mono font-medium break-words whitespace-pre-line'),
                    'data-role'(text)
                ], [])
            ])
        ]),
        template([id('mm-template-appearance')], [
            div([
                class('flex flex-wrap items-center gap-2 rounded-lg border px-3 py-2'),
                'data-role'(row)
            ], [
                span([class(LabelClass), 'data-role'('origin-label')], []),
                code([
                    class('font-mono break-all'),
                    'data-role'('origin-value')
                ], []),
                span([class('text-surface-500')], '→'),
                span([class(LabelClass)], 'Atual'),
                code([
                    class('font-mono break-all'),
                    'data-role'('current-value')
                ], []),
                span([
                    class('hidden ml-auto rounded-full border px-2 py-0.5 \c
                           text-[0.65rem] uppercase tracking-wide font-semibold'),
                    'data-role'(badge)
                ], [])
            ])
        ]),
        template([id('mm-template-collected')], [
            span([
                class('flex items-center gap-2 rounded-lg bg-surface-950 \c
                       border border-surface-700 px-2.5 py-1')
            ], [
                span([
                    class('text-base leading-none'),
                    'data-role'(glyph)
                ], []),
                span([
                    class('text-[0.65rem] uppercase tracking-wide font-semibold \c
                           text-surface-500'),
                    'data-role'(kind)
                ], []),
                span([
                    class('font-mono text-surface-200'),
                    'data-role'(name)
                ], [])
            ])
        ]),
        template([id('mm-template-mandate')], [
            div([], [
                div([class('flex items-center gap-2 mb-3 text-surface-200')], [
                    'Suspeito',
                    span([
                        class('rounded-full bg-sky-950 border border-sky-800 \c
                               px-2.5 py-1 font-mono font-semibold text-sky-300'),
                        'data-role'(suspect)
                    ], [])
                ]),
                div([
                    class('flex flex-wrap gap-2'),
                    'data-role'(clues)
                ], [])
            ])
        ]),
        template([id('mm-template-clue')], [
            span([
                class('rounded-lg bg-surface-950 border border-surface-700 \c
                       px-2.5 py-1 font-mono text-surface-300'),
                'data-role'(clue)
            ], [])
        ])
    ]).

state_label_class(
    'text-[0.65rem] uppercase tracking-wide font-semibold text-surface-500'
).
