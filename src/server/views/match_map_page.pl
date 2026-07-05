:- module(match_map_page, [
    content/6
]).

:- use_module(page_section).
:- use_module(ui).

%!  content(+MapName, +ThiefLink, +DetectiveLink, +DetailLink, +DataJson,
%!          -Content) is det.
%
%   Componentes declarativos da pagina do mapa. O JSON contem frames prontos;
%   os templates sao clonados pelo controlador durante o playback.
content(MapName, ThiefLink, DetectiveLink, DetailLink, DataJson, Content) :-
    page_section:back_link(DetailLink, 'Voltar para a partida', BackLink),
    map_controls(Controls),
    map_legend(Legend),
    map_event_card(EventInfo),
    ui:status_chip_class(amber, 'hidden', ThiefIdentityClass),
    map_scroll_card(
        normal,
        amber,
        [
            'Aparência do ladrão',
            span([
                id('mm-thief-identity'),
                class(ThiefIdentityClass)
            ], [])
        ],
        'mm-appearance',
        'space-y-2 overflow-y-auto min-h-0 flex-1 pr-1',
        AppearanceCard
    ),
    loot_view_toggle(LootViewToggle),
    map_scroll_card(
        compact,
        emerald,
        [
            span([], 'Cadeia do tesouro'),
            LootViewToggle
        ],
        'mm-collected',
        'overflow-auto min-h-0 flex-1 pr-1 pb-1',
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
            '  •  Ladrão: ', b([], ThiefLink),
            '  •  Detetive: ', b([], DetectiveLink)
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
            src('/assets/match_map.js?v=44')
        ], [])
    ].

loot_view_toggle(Html) :-
    ui:text_class(
        meta,
        'ml-auto w-52 text-center normal-case tracking-normal',
        ToggleLayout
    ),
    ui:primary_button_class(
        default,
        ToggleLayout,
        Class
    ),
    Html = button([
        type(button),
        id('mm-loot-view-toggle'),
        class(Class),
        'aria-controls'('mm-collected'),
        'aria-label'('Exibir itens coletados como lista'),
        'aria-pressed'(false),
        title('Ver itens coletados')
    ], 'Ver itens coletados').

map_controls(Html) :-
    ui:padded_surface_class(
        normal,
        'mb-4 flex flex-wrap items-center gap-3',
        CardClass
    ),
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
    ui:control_class(compact, 'w-24', IntervalInputClass),
    Html = div([
        class(CardClass),
        role(region),
        'aria-label'('Controles do replay')
    ], [
        p([
            id('mm-keyboard-help'),
            class('sr-only')
        ], 'Atalhos: Espaço reproduz ou pausa; setas esquerda e direita mudam o turno; mais e menos alteram o intervalo.'),
        button([type(button), id('mm-play'), class(PlayClass),
                'aria-label'('Reproduzir'), 'aria-pressed'(false),
                'aria-keyshortcuts'('Space'), title('Reproduzir')], [
            span([id('mm-play-icon'), 'aria-hidden'(true),
                  class('block'), style('transform: translateY(-1px)')], '▶︎')
        ]),
        label([
            for('mm-slider'),
            class('sr-only')
        ], 'Turno da partida'),
        input([type(range), id('mm-slider'), min(0), max(0), value(0), step(1),
               class('flex-1 accent-ufop-500'),
               'aria-describedby'('mm-keyboard-help'),
               'aria-keyshortcuts'('ArrowLeft ArrowRight'),
               'aria-valuetext'('Início')]),
        span([
            id('mm-turn-label'),
            class(TurnClass),
            role(status),
            'aria-live'(polite),
            'aria-atomic'(true)
        ], 'Início'),
        label([class(IntervalClass)], [
            'Intervalo',
            input([type(number), id('mm-interval'), value(500), min(100),
                   step(100),
                   'aria-describedby'('mm-keyboard-help'),
                   'aria-keyshortcuts'('+ -'),
                   class(IntervalInputClass)]),
            'ms'
        ])
    ]).

% `map-wide` fica definido na configuracao global do Tailwind (page.pl).
map_replay_layout(AppearanceCard, CollectedCard, Html) :-
    ui:surface_class(
        'relative overflow-hidden order-first lg:order-none',
        GraphClass
    ),
    ui:text_class(
        meta,
        'absolute right-3 top-3 z-30',
        ResetLayout
    ),
    ui:primary_button_class(
        small,
        ResetLayout,
        ResetClass
    ),
    map_resize_handles(ResizeHandles),
    GraphCanvas = div([
        id('mm-graph-canvas'),
        class('h-full min-h-0')
    ], []),
    ResetButton = button([
        type(button),
        id('mm-map-size-reset'),
        class(ResetClass),
        title('Restaurar dimensões do mapa'),
        'aria-controls'('mm-replay-layout'),
        'aria-label'('Restaurar dimensões do mapa')
    ], 'Resetar layout'),
    GraphChildren = [GraphCanvas, ResetButton|ResizeHandles],
    LeftPanel = div([
        id('mm-left-panel'),
        class('min-w-0')
    ], [AppearanceCard]),
    Html = div([
        id('mm-replay-layout'),
        class('grid gap-4 mb-4 lg:items-start \c
               lg:grid-cols-[minmax(16rem,_20rem)_minmax(0,_1fr)] \c
               xl:grid-cols-[minmax(16rem,_1fr)_var(--mm-graph-width)] \c
               map-wide:grid-cols-[var(--mm-left-width)_var(--mm-graph-width)_minmax(12rem,_1fr)]'),
        style('--mm-graph-width:56rem;\c
               --mm-left-width:minmax(12rem,1fr);\c
               --mm-right-width:20rem')
    ], [
        LeftPanel,
        div([
            id('mm-graph'),
            class(GraphClass),
            role(region),
            'aria-label'('Grafo do mapa da partida'),
            'aria-describedby'('mm-keyboard-help')
        ], GraphChildren),
        div([
            id('mm-right-panel'),
            class('min-w-0 lg:col-span-2 map-wide:col-span-1')
        ],
            [CollectedCard])
    ]).

map_resize_handles([
    div([
        id('mm-resize-left'),
        class('group absolute inset-y-0 left-0 z-20 hidden w-3 \c
               cursor-ew-resize touch-none items-center justify-center \c
               focus:outline-none focus-visible:ring-2 \c
               focus-visible:ring-inset focus-visible:ring-ufop-400 xl:flex'),
        role(separator),
        tabindex(0),
        'aria-orientation'(vertical),
        'aria-valuemin'(448),
        'aria-valuenow'(896),
        'aria-valuetext'('Largura padrão do mapa'),
        'aria-controls'('mm-left-panel mm-graph'),
        'aria-keyshortcuts'('ArrowLeft ArrowRight'),
        'aria-label'('Redimensionar mapa pela lateral esquerda'),
        title('Arraste para redimensionar o mapa')
    ], [
        span([class('h-16 w-1 rounded-full bg-surface-400 opacity-40 \c
                     transition group-hover:opacity-100 \c
                     group-focus:opacity-100')], [])
    ]),
    div([
        id('mm-resize-right'),
        class('group absolute inset-y-0 right-0 z-20 hidden w-3 \c
               cursor-ew-resize touch-none items-center justify-center \c
               focus:outline-none focus-visible:ring-2 \c
               focus-visible:ring-inset focus-visible:ring-ufop-400 \c
               map-wide:flex'),
        role(separator),
        tabindex(0),
        'aria-orientation'(vertical),
        'aria-valuemin'(448),
        'aria-valuenow'(896),
        'aria-valuetext'('Largura padrão do mapa'),
        'aria-controls'('mm-right-panel mm-graph'),
        'aria-keyshortcuts'('ArrowLeft ArrowRight'),
        'aria-label'('Redimensionar mapa pela lateral direita'),
        title('Arraste para redimensionar o mapa')
    ], [
        span([class('h-16 w-1 rounded-full bg-surface-400 opacity-40 \c
                     transition group-hover:opacity-100 \c
                     group-focus:opacity-100')], [])
    ]),
    div([
        id('mm-resize-bottom'),
        class('group absolute inset-x-0 bottom-0 z-20 hidden h-3 \c
               cursor-ns-resize touch-none items-center justify-center \c
               focus:outline-none focus-visible:ring-2 \c
               focus-visible:ring-inset focus-visible:ring-ufop-400 lg:flex'),
        role(separator),
        tabindex(0),
        'aria-orientation'(horizontal),
        'aria-valuemin'(320),
        'aria-valuemax'(1200),
        'aria-valuenow'(620),
        'aria-valuetext'('Altura padrão do mapa'),
        'aria-controls'('mm-graph'),
        'aria-keyshortcuts'('ArrowUp ArrowDown'),
        'aria-label'('Redimensionar altura do mapa'),
        title('Arraste para redimensionar a altura')
    ], [
        span([class('h-1 w-16 rounded-full bg-surface-400 opacity-40 \c
                     transition group-hover:opacity-100 \c
                     group-focus:opacity-100')], [])
    ])
]).

map_legend(Html) :-
    ui:text_class(
        meta,
        'grid grid-cols-2 gap-x-3 gap-y-2 mb-4 \c
         sm:flex sm:flex-wrap sm:items-center sm:gap-x-5 sm:gap-y-2',
        Class
    ),
    legend_item('rounded-full bg-amber-400', 'Rota do ladrão', Thief),
    legend_item('rounded-full bg-sky-400', 'Rota do detetive', Detective),
    legend_item(
        'rounded bg-ufop-600 border border-ufop-200',
        'Cidade bloqueada',
        Blocked
    ),
    legend_item(
        'rounded bg-emerald-600 border border-emerald-300',
        'Objetivo liberado',
        Ready
    ),
    legend_item(
        'rounded bg-amber-400 border border-amber-200',
        'Evento de furto',
        Robbery
    ),
    legend_item(
        'rounded bg-sky-900 border border-sky-400',
        'Cidade inspecionada',
        Inspection
    ),
    Html = div([
        class(Class),
        role(group),
        'aria-label'('Legenda do mapa')
    ], [
        Thief, Detective, Blocked, Ready, Robbery, Inspection
    ]).

legend_item(ColorClass, Label,
            span([class('min-w-0 flex items-center gap-2 leading-tight')], [
                span([class(Class), 'aria-hidden'(true)], []),
                Label
            ])) :-
    atomic_list_concat(
        ['inline-block shrink-0 w-3 h-3', ColorClass],
        ' ',
        Class
    ).

map_event_card(Html) :-
    ui:surface_class('overflow-hidden', CardClass),
    ui:eyebrow_class(amber, AccentClass),
    atomic_list_concat([AccentClass, 'px-4 pt-4 pb-2'], ' ', HeadingClass),
    event_side('Ladrão', thief, ThiefSide),
    event_side('Detetive', detective, DetectiveSide),
    Html = div([
        class(CardClass),
        role(region),
        'aria-label'('Eventos do turno')
    ], [
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

map_scroll_card(Density, Accent, Label, Id, ContentClass, Html) :-
    ui:panel_header_class(Accent, 'shrink-0', HeadingClass),
    ui:padded_surface_class(
        Density,
        'flex flex-col overflow-hidden js-map-height',
        CardClass
    ),
    map_panel_label(Id, PanelLabel),
    Html = div([
        class(CardClass),
        role(region),
        'aria-label'(PanelLabel)
    ], [
        div([class(HeadingClass)], Label),
        div([id(Id), class(ContentClass)], [])
    ]).

map_state_card(Accent, Label, Id, Html) :-
    ui:panel_header_class(Accent, HeadingClass),
    ui:padded_surface_class(normal, CardClass),
    Html = div([
        class(CardClass),
        role(region),
        'aria-label'(Label)
    ], [
        p([class(HeadingClass)], Label),
        div([id(Id), class('space-y-2')], [])
    ]).

map_panel_label('mm-appearance', 'Aparência do ladrão').
map_panel_label('mm-collected', 'Cadeia do tesouro').

map_templates(Html) :-
    ui:event_row_base_class(EventRowClass),
    atomic_list_concat(
        [EventRowClass, 'flex flex-wrap items-center gap-2'],
        ' ',
        AppearanceRowClass
    ),
    ui:micro_badge_class('hidden ml-auto', AppearanceBadgeClass),
    ui:micro_badge_class(
        'shrink-0 border-current',
        LootStatusClass
    ),
    ui:inset_item_class(
        'flex items-center gap-2',
        CollectedListClass
    ),
    ui:micro_label_class('text-surface-500', ListKindClass),
    ui:text_class(meta, 'hidden truncate opacity-70', LootCityClass),
    ui:status_chip_class(sky, SuspectClass),
    ui:inset_item_class('font-mono text-surface-300', ClueClass),
    Html = div([class('hidden'), 'aria-hidden'(true)], [
        % Classes aplicadas dinamicamente aos clones; mantidas no HTML para o
        % compilador Tailwind CDN gerar todos os estados antes do playback.
        span([class('border-reveal-border bg-reveal-surface/40 \c
                     bg-reveal-surface text-reveal-text border-sky-800 \c
                     bg-sky-950/40 bg-sky-950 text-sky-200 text-sky-300 \c
                     border-amber-800 border-amber-900/60 bg-amber-950/40 \c
                     text-amber-200 text-amber-300 border-emerald-800 \c
                     bg-emerald-950/40 text-emerald-200 text-emerald-300 \c
                     border-surface-700 bg-surface-950 text-ufop-400 \c
                     text-surface-300')], []),
        template([id('mm-template-empty')], [
            p([
                class('text-surface-500 italic'),
                'data-role'(message)
            ], [])
        ]),
        template([id('mm-template-turn-event')], [
            div([
                class(EventRowClass)
            ], [
                p([
                    class('font-mono font-medium break-words whitespace-pre-line'),
                    'data-role'(text)
                ], [])
            ])
        ]),
        template([id('mm-template-appearance')], [
            div([
                class(AppearanceRowClass),
                'data-role'(row)
            ], [
                code([
                    class('font-mono break-all text-surface-200'),
                    'data-role'('origin-value')
                ], []),
                span([
                    class('hidden text-surface-500'),
                    'data-role'(arrow)
                ], [
                    span(['aria-hidden'(true)], '→'),
                    span([class('sr-only')], 'alterado para')
                ]),
                code([
                    class('hidden font-mono break-all'),
                    'data-role'('current-value')
                ], []),
                span([
                    class(AppearanceBadgeClass),
                    'data-role'(badge)
                ], [])
            ])
        ]),
        template([id('mm-template-collected')], [
            li([
                class('min-w-0')
            ], [
                div([
                    class('flex min-w-72 items-center gap-1.5 rounded-lg \c
                           border px-2 py-1.5'),
                    'data-role'(node)
                ], [
                    span([
                        class('shrink-0 text-base leading-none'),
                        'aria-hidden'(true),
                        'data-role'(glyph)
                    ], []),
                    div([class('min-w-0 flex-1')], [
                        span([
                            class('sr-only'),
                            'data-role'(kind)
                        ], []),
                        div([class('min-w-0')], [
                            span([
                                class('font-mono font-semibold whitespace-nowrap'),
                                'data-role'(name)
                            ], []),
                            div([
                                class(LootCityClass),
                                'data-role'(city)
                            ], [])
                        ])
                    ]),
                    span([
                        class(LootStatusClass),
                        'data-role'(status)
                    ], [])
                ]),
                ul([
                    class('ml-1.5 mt-1.5 space-y-1.5 border-l \c
                           border-surface-700 pl-2'),
                    'data-role'(children)
                ], [])
            ])
        ]),
        template([id('mm-template-collected-list-item')], [
            span([
                class(CollectedListClass)
            ], [
                span([
                    class('text-base leading-none'),
                    'data-role'(glyph)
                ], []),
                span([
                    class(ListKindClass),
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
                        class(SuspectClass),
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
                class(ClueClass),
                'data-role'(clue)
            ], [])
        ])
    ]).
