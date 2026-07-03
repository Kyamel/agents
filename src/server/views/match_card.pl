:- module(match_card, [
    match_card/2,
    winner_label/3
]).

:- use_module(ui).

match_card(Match, Html) :-
    Id = Match.id,
    atom_concat('/matches/', Id, Href),
    winner_label(Match.winner, WinnerText, BadgeClass),
    agent_name(Match, thief_agent_name, thief_agent_id, ThiefName),
    agent_name(Match, detective_agent_name, detective_agent_id, DetectiveName),
    ui:text_class(normal, 'font-mono font-semibold', MatchLinkTextClass),
    ui:link_class(MatchLinkTextClass, LinkClass),
    ui:text_class(normal, 'mt-1 grid gap-0.5', DetailsClass),
    ui:text_class(auxiliary,
                  'mt-1 min-w-0 text-surface-500 truncate',
                  CreatedClass),
    ui:surface_class('p-3 hover:border-surface-600 transition',
                     CardClass),
    Html = article([class(CardClass)], [
        div([class('flex items-center justify-between gap-2')], [
            a([href(Href), class(LinkClass)], ['Partida #', Id]),
            span([class(BadgeClass)], WinnerText)
        ]),
        dl([class(DetailsClass)], [
            div([class('grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2')], [
                dt([class('text-surface-500')], 'Ladrão'),
                dd([title(ThiefName),
                    class('min-w-0 truncate font-medium text-surface-200')],
                   ThiefName)
            ]),
            div([class('grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2')], [
                dt([class('text-surface-500')], 'Detetive'),
                dd([title(DetectiveName),
                    class('min-w-0 truncate font-medium text-surface-200')],
                   DetectiveName)
            ])
        ]),
        p([class(CreatedClass)],
          ['Criada em ', Match.created_at])
    ]).

agent_name(Match, NameKey, _IdKey, Name) :-
    get_dict(NameKey, Match, Name),
    Name \== "",
    !.
agent_name(Match, _NameKey, IdKey, Name) :-
    get_dict(IdKey, Match, Name).

% Vencedor -> rotulo + classe da etiqueta. Reutilizado por match_detail.
winner_label(thief, 'Vitória do ladrão', Class) :- !, badge_class(amber, Class).
winner_label("thief", 'Vitória do ladrão', Class) :- !, badge_class(amber, Class).
winner_label(detective, 'Vitória do detetive', Class) :- !, badge_class(sky, Class).
winner_label("detective", 'Vitória do detetive', Class) :- !, badge_class(sky, Class).
winner_label(_, 'Empate', Class) :- badge_class(slate, Class).

badge_class(amber,
    'rounded-full bg-amber-950 text-amber-300 text-sm leading-5 px-2.5 py-1 whitespace-nowrap').
badge_class(emerald,
    'rounded-full bg-emerald-950 text-emerald-300 text-sm leading-5 px-2.5 py-1 whitespace-nowrap').
badge_class(sky,
    'rounded-full bg-sky-950 text-sky-300 text-sm leading-5 px-2.5 py-1 whitespace-nowrap').
badge_class(slate,
    'rounded-full bg-surface-800 text-surface-300 text-sm leading-5 px-2.5 py-1 whitespace-nowrap').
