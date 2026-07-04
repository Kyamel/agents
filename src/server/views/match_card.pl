:- module(match_card, [
    match_card/2,
    winner_label/3
]).

:- use_module(ui).

match_card(Match, Html) :-
    Id = Match.id,
    atom_concat('/matches/', Id, Href),
    match_badge(Match.status, Match.winner, WinnerText, BadgeClass),
    agent_name(Match, thief_agent_name, thief_agent_id, ThiefName),
    agent_name(Match, detective_agent_name, detective_agent_id, DetectiveName),
    ui:text_class(normal, 'font-mono font-semibold', MatchLinkTextClass),
    ui:link_class(MatchLinkTextClass, LinkClass),
    ui:text_class(normal, 'mt-1 grid gap-0.5', DetailsClass),
    ui:text_class(meta,
                  'mt-1 min-w-0 text-surface-500 truncate',
                  CreatedClass),
    ui:surface_class('p-3 transition',
                     CardClass),
    ui:local_time(Match.created_at, CreatedTime),
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
          ['Criada em ', CreatedTime])
    ]).

agent_name(Match, NameKey, _IdKey, Name) :-
    get_dict(NameKey, Match, Name),
    Name \== "",
    !.
agent_name(Match, _NameKey, IdKey, Name) :-
    get_dict(IdKey, Match, Name).

% Enquanto a partida nao terminou, o card mostra o estado da execucao em vez
% de interpretar o vencedor vazio como empate.
match_badge("queued", _Winner, 'Na fila', Class) :-
    !,
    badge_class(amber, Class).
match_badge("running", _Winner, 'Em execução', Class) :-
    !,
    badge_class(emerald, Class).
match_badge("timeout", _Winner, 'Tempo esgotado', Class) :-
    !,
    badge_class(ufop, Class).
match_badge("error", _Winner, 'Falha na execução', Class) :-
    !,
    badge_class(ufop, Class).
match_badge("done", Winner, Text, Class) :-
    !,
    winner_label(Winner, Text, Class).
match_badge(_Status, _Winner, 'Status desconhecido', Class) :-
    badge_class(slate, Class).

% Vencedor -> rotulo + classe da etiqueta. Reutilizado por match_detail.
winner_label("thief", 'Vitória do ladrão', Class) :- !, badge_class(amber, Class).
winner_label("detective", 'Vitória do detetive', Class) :- !, badge_class(sky, Class).
winner_label("draw", 'Empate', Class) :- !, badge_class(slate, Class).
winner_label(_, 'Resultado indisponível', Class) :- badge_class(slate, Class).

badge_class(amber, Class)   :- ui:pill_class(amber, Class).
badge_class(emerald, Class) :- ui:pill_class(emerald, Class).
badge_class(ufop, Class)    :- ui:pill_class(ufop, Class).
badge_class(sky, Class)     :- ui:pill_class(sky, Class).
badge_class(slate, Class)   :- ui:pill_class(neutral, Class).
