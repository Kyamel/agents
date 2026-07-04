:- module(match_detail, [
    stat_card/3,
    stat_card/4,
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
    ui:padded_surface_class(normal, 'mb-8', CardClass),
    ui:text_class(section, 'mb-4', HeadingClass),
    ui:text_class(normal, 'grid sm:grid-cols-3 gap-x-6 gap-y-4', GridClass),
    ui:eyebrow_class(slate, EyebrowBase),
    atomic_list_concat([EyebrowBase, 'mb-2'], ' ', AppearanceClass),
    Html = div([class(CardClass)], [
        h2([class(HeadingClass)], 'Configuração da partida'),
        div([class(GridClass)], [F1, F2, F3, F4, F5, F6]),
        div([class('mt-5')], [
            p([class(AppearanceClass)], 'Aparencia do alvo'),
            div([class('flex flex-wrap gap-2')], Chips)
        ])
    ]).

fact(Label, Value, div([], [
        dt([class(LabelClass)], Label),
        dd([class('font-medium mt-0.5 break-all')], Value)
    ])) :-
    ui:eyebrow_class(slate, LabelClass).

appearance_chips(Setup, Chips) :-
    get_dict(appearance, Setup, Attrs),
    is_list(Attrs),
    Attrs \= [],
    !,
    maplist(chip, Attrs, Chips).
appearance_chips(_Setup, [span([class(Class)], '-')]) :-
    ui:text_class(normal, 'text-surface-500', Class).

chip(Text, span([class(Class)], Text)) :-
    ui:pill_class(neutral, Class).

events_section([], Html) :-
    !,
    ui:text_class(section, 'mb-3', HeadingClass),
    ui:text_class(normal, 'text-surface-500', EmptyClass),
    Html = div([class('mb-8')], [
        h2([class(HeadingClass)], 'Eventos'),
        p([class(EmptyClass)], 'Nenhum evento registrado nesta partida.')
    ]).
events_section(Events, Html) :-
    maplist(event_item, Events, Items),
    ui:text_class(section, 'mb-3', HeadingClass),
    Html = div([class('mb-8')], [
        h2([class(HeadingClass)], 'Eventos'),
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
    ui:text_class(
        normal,
        'text-amber-200 font-medium break-words',
        TitleClass
    ),
    ui:text_class(
        meta,
        'text-amber-200/70 mt-0.5 break-words',
        RevealedClass
    ),
    ui:event_row_class(amber, CardClass),
    Html = li([class(CardClass)], [
        p([class(TitleClass)], Title),
        p([class(RevealedClass)], Revealed)
    ]).
event_item(Event, Html) :-
    get_dict(type, Event, Type),
    event_tone(Type, CardClass, TextClass),
    !,
    field_text(Event, turn, Turn),
    field_text(Event, text, Detail),
    format(string(Text), "Turno ~w: ~w", [Turn, Detail]),
    Html = li([class(CardClass)], [
        p([class(TextClass)], Text)
    ]).
event_item(Event, Html) :-
    field_text(Event, turn, Turn),
    field_text(Event, detail, Detail),
    format(string(Text), "Turno ~w: ~w", [Turn, Detail]),
    ui:event_row_class(neutral, RowClass),
    atomic_list_concat([RowClass, 'break-words'], ' ', RowWithBreak),
    ui:text_class(normal, RowWithBreak, LiClass),
    Html = li([class(LiClass)], Text).

event_tone(
    "disguise",
    CardClass,
    'text-reveal-text font-medium break-words'
) :-
    ui:event_row_class(reveal, CardClass).
event_tone(
    "mandate",
    CardClass,
    'text-emerald-200 font-medium break-words'
) :-
    ui:event_row_class(emerald, CardClass).
event_tone(
    "inspection",
    CardClass,
    'text-sky-200 font-medium break-words'
) :-
    ui:event_row_class(sky, CardClass).

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
    stat_card(Label, Value, '', Html).

% ValueColor: classe de cor extra para o numero (ex.: 'text-emerald-300');
% '' mantem o valor neutro (aparencia padrao do resto do app).
stat_card(Label, Value, '', Html) :-
    !,
    render_stat(Label, Value, 'font-semibold mt-1 break-all', Html).
stat_card(Label, Value, ValueColor, Html) :-
    atomic_list_concat(['font-semibold mt-1 break-all', ValueColor], ' ', ValueClass),
    render_stat(Label, Value, ValueClass, Html).

render_stat(Label, Value, ValueClass, div([class(CardClass)], [
        p([class(LabelClass)], Label),
        p([class(ValueClass)], Value)
    ])) :-
    ui:padded_surface_class(normal, CardClass),
    ui:eyebrow_class(slate, LabelClass).

winner_card(Winner, Html) :-
    match_card:winner_label(Winner, Text, _),
    winner_card_class(Winner, CardClass),
    winner_accent(Winner, Accent),
    ui:eyebrow_class(Accent, LabelClass),
    ui:text_class(emphasis, 'mt-1', ResultClass),
    Html = div([class(CardClass)], [
        p([class(LabelClass)], 'Resultado'),
        p([class(ResultClass)], Text)
    ]).

winner_accent("thief", amber) :- !.
winner_accent("detective", sky) :- !.
winner_accent(_, slate).

winner_card_class("thief", C) :- !, ui:tinted_card_class(amber, C).
winner_card_class("detective", C) :- !, ui:tinted_card_class(sky, C).
winner_card_class(_, C) :- ui:tinted_card_class(neutral, C).

turns_table([], Html) :-
    !,
    page_section:empty_state('Replay indisponivel para esta partida.', Html).
turns_table(Turns, Html) :-
    maplist(turn_row, Turns, Rows),
    ui:text_class(normal, 'w-full table-fixed', TableClass),
    ui:table_cell_class('text-left break-words', HeaderCellClass),
    Html = div([class('overflow-x-auto rounded-xl border border-surface-700')], [
        table([class(TableClass)], [
            caption([class('sr-only')], 'Replay turno a turno'),
            colgroup([], [
                col([class('w-[10%]')]),
                col([class('w-[30%]')]),
                col([class('w-[15%]')]),
                col([class('w-[30%]')]),
                col([class('w-[15%]')])
            ]),
            thead([class('bg-surface-900 text-surface-400')], [
                tr([], [
                    th([scope(col), class(HeaderCellClass)], 'Turno'),
                    th([scope(col), class(HeaderCellClass)], 'Ação ladrão'),
                    th([scope(col), class(HeaderCellClass)], 'Pos. ladrão'),
                    th([scope(col), class(HeaderCellClass)], 'Ação detetive'),
                    th([scope(col), class(HeaderCellClass)], 'Pos. detetive')
                ])
            ]),
            tbody([], Rows)
        ])
    ]).

turn_row(Turn, tr([class('border-t border-surface-700')], [
        th([scope(row), class(MetaCellClass)], TurnNo),
        td([class(ThiefClass)], ThiefAction),
        td([class(MetaCellClass)], ThiefPos),
        td([class(DetectiveClass)], DetectiveAction),
        td([class(MetaCellClass)], DetectivePos)
    ])) :-
    field_text(Turn, turn, TurnNo),
    field_text(Turn, thief_action, ThiefAction),
    field_text(Turn, thief_position, ThiefPos),
    field_text(Turn, detective_action, DetectiveAction),
    field_text(Turn, detective_position, DetectivePos),
    ui:table_cell_class(
        'font-normal text-surface-400 break-words whitespace-normal',
        MetaCellClass
    ),
    action_class(Turn, thief_status, ThiefClass),
    action_class(Turn, detective_status, DetectiveClass).

action_class(Turn, StatusKey, Class) :-
    get_dict(StatusKey, Turn, "Ilegal"),
    !,
    ui:table_cell_class(
        'text-ufop-400 break-words whitespace-normal',
        Class
    ).
action_class(_Turn, _StatusKey, Class) :-
    ui:table_cell_class('break-words whitespace-normal', Class).

render_not_found(Request) :-
    ui:link_class(LinkClass),
    ui:text_class(title, 'mb-2', HeadingClass),
    ui:text_class(normal, 'text-surface-400 mb-6', DescClass),
    page:reply_page(Request, 'Partida não encontrada', [
        h1([class(HeadingClass)], 'Partida não encontrada'),
        p([class(DescClass)], 'Não existe partida com esse identificador.'),
        a([href('/matches'), class(LinkClass)], 'Voltar para partidas')
    ]).
