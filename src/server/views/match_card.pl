:- module(match_card, [
    match_card/2,
    winner_label/3
]).

:- use_module(ui).

match_card(Match, Html) :-
    Id = Match.id,
    atom_concat('/matches/', Id, Href),
    winner_label(Match.winner, WinnerText, BadgeClass),
    ui:surface_class('p-3 hover:border-surface-600 transition', CardClass),
    ui:link_class('min-w-0 truncate font-mono text-xs', LinkClass),
    Html = div([class(CardClass)], [
        div([class('flex items-center justify-between gap-2')], [
            a([href(Href),
               title(Id),
               class(LinkClass)],
              Id),
            span([class(BadgeClass)], WinnerText)
        ]),
        dl([class('mt-3 grid gap-1 text-xs')], [
            div([class('grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2')], [
                dt([class('text-surface-500')], 'Ladrão'),
                dd([title(Match.thief_agent_id), class('min-w-0 truncate font-mono text-surface-400')],
                   Match.thief_agent_id)
            ]),
            div([class('grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2')], [
                dt([class('text-surface-500')], 'Detetive'),
                dd([title(Match.detective_agent_id), class('min-w-0 truncate font-mono text-surface-400')],
                   Match.detective_agent_id)
            ])
        ]),
        p([class('text-surface-600 text-xs mt-2 truncate')], ['Criada em ', Match.created_at])
    ]).

% Vencedor -> rotulo + classe da etiqueta. Reutilizado por match_detail.
winner_label(thief, 'Vitória do ladrão', Class) :- !, badge_class(amber, Class).
winner_label("thief", 'Vitória do ladrão', Class) :- !, badge_class(amber, Class).
winner_label(detective, 'Vitória do detetive', Class) :- !, badge_class(sky, Class).
winner_label("detective", 'Vitória do detetive', Class) :- !, badge_class(sky, Class).
winner_label(_, 'Empate', Class) :- badge_class(slate, Class).

badge_class(amber,
    'rounded-full bg-amber-950 text-amber-300 text-xs px-2.5 py-1 whitespace-nowrap').
badge_class(emerald,
    'rounded-full bg-emerald-950 text-emerald-300 text-xs px-2.5 py-1 whitespace-nowrap').
badge_class(sky,
    'rounded-full bg-sky-950 text-sky-300 text-xs px-2.5 py-1 whitespace-nowrap').
badge_class(slate,
    'rounded-full bg-surface-800 text-surface-300 text-xs px-2.5 py-1 whitespace-nowrap').
