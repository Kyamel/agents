:- module(match_detail, [
    stat_card/3,
    winner_card/2,
    setup_section/2,
    events_section/2,
    turns_table/2,
    field_text/3,
    render_not_found/1
]).

:- use_module(match_card).
:- use_module(page).
:- use_module(page_section).
:- use_module(ui).

setup_section(Setup, Html) :-
    field_text(Setup, scenario, Scenario),
    field_text(Setup, target, Target),
    field_text(Setup, max_turns, MaxTurns),
    field_text(Setup, thief_start, ThiefStart),
    field_text(Setup, detective_start, DetectiveStart),
    field_text(Setup, disguises, Disguises),
    fact('Cenario', Scenario, F1),
    fact('Alvo do ladrao', Target, F2),
    fact('Limite de turnos', MaxTurns, F3),
    fact('Inicio do ladrao', ThiefStart, F4),
    fact('Inicio do detetive', DetectiveStart, F5),
    fact('Disfarces disponíveis', Disguises, F6),
    appearance_chips(Setup, Chips),
    ui:surface_class('p-4 mb-8', CardClass),
    Html = div([class(CardClass)], [
        h2([class('font-semibold mb-4')], 'Configuração da partida'),
        div([class('grid sm:grid-cols-3 gap-x-6 gap-y-4 text-sm')],
            [F1, F2, F3, F4, F5, F6]),
        div([class('mt-5')], [
            p([class('text-surface-500 text-xs uppercase tracking-wide mb-2')],
              'Aparencia do alvo'),
            div([class('flex flex-wrap gap-2')], Chips)
        ])
    ]).

fact(Label, Value, div([], [
        dt([class('text-surface-500 text-xs uppercase tracking-wide')], Label),
        dd([class('font-medium mt-0.5 break-all')], Value)
    ])).

appearance_chips(Setup, Chips) :-
    get_dict(appearance, Setup, Attrs),
    is_list(Attrs),
    Attrs \= [],
    !,
    maplist(chip, Attrs, Chips).
appearance_chips(_Setup, [span([class('text-surface-500 text-sm')], '-')]).

chip(Text, span([class('inline-block rounded-full bg-surface-800 text-surface-300 \c
                        px-3 py-1 text-xs')], Text)).

events_section([], Html) :-
    !,
    Html = div([class('mb-8')], [
        h2([class('font-semibold mb-3')], 'Eventos'),
        p([class('text-surface-500 text-sm')], 'Nenhum roubo registrado nesta partida.')
    ]).
events_section(Events, Html) :-
    maplist(event_item, Events, Items),
    Html = div([class('mb-8')], [
        h2([class('font-semibold mb-3')], 'Eventos'),
        ul([class('space-y-2')], Items)
    ]).

event_item(Event, Html) :-
    get_dict(type, Event, "robbery"),
    !,
    field_text(Event, turn, Turn),
    field_text(Event, item, Item),
    field_text(Event, city, City),
    revealed_text(Event, Revealed),
    format(string(Title), "Turno ~w: roubo de ~w em ~w", [Turn, Item, City]),
    Html = li([class('rounded-lg bg-amber-950/40 border border-amber-900/60 px-3 py-2')], [
        p([class('text-amber-200 text-sm font-medium')], Title),
        p([class('text-amber-200/70 text-xs mt-0.5')], Revealed)
    ]).
event_item(Event, Html) :-
    field_text(Event, turn, Turn),
    field_text(Event, detail, Detail),
    format(string(Text), "Turno ~w: ~w", [Turn, Detail]),
    Html = li([class('rounded-lg bg-surface-900 border border-surface-800 px-3 py-2 \c
                      text-surface-300 text-sm')], Text).

revealed_text(Event, Text) :-
    get_dict(revealed, Event, Revealed),
    is_list(Revealed),
    Revealed \= [],
    !,
    atomic_list_concat(Revealed, ', ', Joined),
    format(string(Text), "Pistas reveladas: ~w", [Joined]).
revealed_text(_Event, "Sem novas pistas.").

% Campo do dict como texto exibivel, com traco como fallback.
field_text(Dict, Key, Text) :-
    get_dict(Key, Dict, Value),
    !,
    format(string(Text), "~w", [Value]).
field_text(_Dict, _Key, "-").

stat_card(Label, Value, Html) :-
    ui:surface_class('p-4', CardClass),
    Html = div([class(CardClass)], [
        p([class('text-surface-500 text-xs uppercase tracking-wide')], Label),
        p([class('font-semibold mt-1 break-all')], Value)
    ]).

winner_card(Winner, Html) :-
    match_card:winner_label(Winner, Text, _),
    winner_card_class(Winner, CardClass),
    Html = div([class(CardClass)], [
        p([class('text-xs uppercase tracking-wide opacity-80')], 'Resultado'),
        p([class('font-semibold mt-1')], Text)
    ]).

winner_card_class(thief, C) :- !, amber_card(C).
winner_card_class("thief", C) :- !, amber_card(C).
winner_card_class(detective, C) :- !, emerald_card(C).
winner_card_class("detective", C) :- !, emerald_card(C).
winner_card_class(_, 'rounded-xl bg-surface-900 p-4 border border-surface-700 text-surface-200').

amber_card('rounded-xl bg-amber-950 p-4 border border-amber-800 text-amber-200').
emerald_card('rounded-xl bg-emerald-950 p-4 border border-emerald-800 text-emerald-200').

turns_table([], Html) :-
    !,
    page_section:empty_state('Replay indisponivel para esta partida.', Html).
turns_table(Turns, Html) :-
    maplist(turn_row, Turns, Rows),
    Html = div([class('overflow-x-auto rounded-xl border border-surface-800')], [
        table([class('w-full text-sm')], [
            thead([class('bg-surface-900 text-surface-400')], [
                tr([], [
                    th([class('text-left px-3 py-2')], 'Turno'),
                    th([class('text-left px-3 py-2')], 'Ação ladrão'),
                    th([class('text-left px-3 py-2')], 'Pos. ladrão'),
                    th([class('text-left px-3 py-2')], 'Ação detetive'),
                    th([class('text-left px-3 py-2')], 'Pos. detetive')
                ])
            ]),
            tbody([], Rows)
        ])
    ]).

turn_row(Turn, tr([class('border-t border-surface-800')], [
        td([class('px-3 py-2 text-surface-400')], TurnNo),
        td([class(ThiefClass)], ThiefAction),
        td([class('px-3 py-2 text-surface-400')], ThiefPos),
        td([class(DetectiveClass)], DetectiveAction),
        td([class('px-3 py-2 text-surface-400')], DetectivePos)
    ])) :-
    field_text(Turn, turn, TurnNo),
    field_text(Turn, thief_action, ThiefAction),
    field_text(Turn, thief_position, ThiefPos),
    field_text(Turn, detective_action, DetectiveAction),
    field_text(Turn, detective_position, DetectivePos),
    action_class(Turn, thief_status, ThiefClass),
    action_class(Turn, detective_status, DetectiveClass).

action_class(Turn, StatusKey, 'px-3 py-2 text-rose-400') :-
    get_dict(StatusKey, Turn, "Ilegal"),
    !.
action_class(_Turn, _StatusKey, 'px-3 py-2').

render_not_found(Request) :-
    ui:link_class(LinkClass),
    page:reply_page(Request, 'Partida não encontrada', [
        h1([class('text-2xl font-bold mb-2')], 'Partida não encontrada'),
        p([class('text-surface-400 mb-6')],
          'Não existe partida com esse identificador.'),
        a([href('/matches'), class(LinkClass)],
          'Voltar para partidas')
    ]).
