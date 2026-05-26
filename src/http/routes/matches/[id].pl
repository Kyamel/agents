:- module(route_matches_show, [
    render/2,
    render_not_found/1,
    render_invalid/1
]).

:- use_module(library(http/html_write)).
:- use_module(library(http/json)).
:- use_module(library(apply)).
:- use_module('../../../db/sqlite_store').
:- use_module('../../../components/layout/page').
:- use_module('../../../components/cards/match_card').

%!  render(+Request, +MatchId) is det.
%
%   Renderiza os detalhes e o replay de uma partida.
render(Request, Id) :-
    (   sqlite_store:get_match(Id, Match)
    ->  render_detail(Request, Match)
    ;   render_not_found(Request)
    ).

render_detail(Request, Match) :-
    agent_display_name(Match.thief_agent_id, ThiefName),
    agent_display_name(Match.detective_agent_id, DetectiveName),
    stat_card('Ladrao', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    winner_card(Match.winner, WinnerCard),
    replay_turns(Match.replay_json, Turns),
    turns_table(Turns, TableHtml),
    page:reply_page(Request, 'Detalhe da partida', [
        a([href('/matches'), class('text-sm text-ufop-400 hover:underline')],
          'Voltar para partidas'),
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Detalhe da partida'),
        p([class('font-mono text-xs text-slate-500 mb-5 break-all')], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-8')], [
            ThiefCard, DetectiveCard, WinnerCard
        ]),
        h2([class('font-semibold mb-3')], 'Replay turno a turno'),
        TableHtml
    ]).

agent_display_name(AgentId, Name) :-
    (   sqlite_store:get_agent(AgentId, Agent)
    ->  Name = Agent.name
    ;   Name = AgentId
    ).

stat_card(Label, Value, Html) :-
    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        p([class('text-slate-500 text-xs uppercase tracking-wide')], Label),
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
winner_card_class(_, 'rounded-xl bg-slate-900 p-4 border border-slate-700 text-slate-200').

amber_card('rounded-xl bg-amber-950 p-4 border border-amber-800 text-amber-200').
emerald_card('rounded-xl bg-emerald-950 p-4 border border-emerald-800 text-emerald-200').

replay_turns(ReplayJson, Turns) :-
    (   catch(atom_json_dict(ReplayJson, Parsed, []), _, fail),
        is_list(Parsed)
    ->  Turns = Parsed
    ;   Turns = []
    ).

turns_table([], Html) :-
    !,
    Html = p([class('text-slate-500 text-sm')], 'Replay indisponivel para esta partida.').
turns_table(Turns, Html) :-
    maplist(turn_row, Turns, Rows),
    Html = div([class('overflow-x-auto rounded-xl border border-slate-800')], [
        table([class('w-full text-sm')], [
            thead([class('bg-slate-900 text-slate-400')], [
                tr([], [
                    th([class('text-left px-3 py-2')], 'Turno'),
                    th([class('text-left px-3 py-2')], 'Acao ladrao'),
                    th([class('text-left px-3 py-2')], 'Pos. ladrao'),
                    th([class('text-left px-3 py-2')], 'Acao detetive'),
                    th([class('text-left px-3 py-2')], 'Pos. detetive')
                ])
            ]),
            tbody([], Rows)
        ])
    ]).

turn_row(Turn, tr([class('border-t border-slate-800')], [
        td([class('px-3 py-2 text-slate-400')], TurnNo),
        td([class('px-3 py-2')], ThiefAction),
        td([class('px-3 py-2 text-slate-400')], ThiefPos),
        td([class('px-3 py-2')], DetectiveAction),
        td([class('px-3 py-2 text-slate-400')], DetectivePos)
    ])) :-
    turn_field(Turn, turn, TurnNo),
    turn_field(Turn, thief_action, ThiefAction),
    turn_field(Turn, thief_position, ThiefPos),
    turn_field(Turn, detective_action, DetectiveAction),
    turn_field(Turn, detective_position, DetectivePos).

turn_field(Turn, Key, Text) :-
    (   get_dict(Key, Turn, Value)
    ->  format(string(Text), "~w", [Value])
    ;   Text = "-"
    ).

% -----------------------------
% Paginas auxiliares
% -----------------------------

render_not_found(Request) :-
    page:reply_page(Request, 'Partida nao encontrada', [
        h1([class('text-2xl font-bold mb-2')], 'Partida nao encontrada'),
        p([class('text-slate-400 mb-6')],
          'Nao existe partida com esse identificador.'),
        a([href('/matches'), class('text-ufop-400 hover:underline')],
          'Voltar para partidas')
    ]).

render_invalid(Request) :-
    page:reply_page(Request, 'Pagina nao encontrada', [
        h1([class('text-2xl font-bold mb-2')], 'Pagina nao encontrada'),
        a([href('/matches'), class('text-ufop-400 hover:underline')],
          'Voltar para partidas')
    ]).
