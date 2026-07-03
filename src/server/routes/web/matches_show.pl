:- module(route_matches_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../../services/matches').
:- use_module('../../views/page').
:- use_module('../../views/match_card').
:- use_module('../../views/match_detail').
:- use_module('../../views/page_section').
:- use_module('../../views/ui').
:- use_module('../../views/button_link').

% Prefix em /matches/ para capturar /matches/<id>. /matches/new tem handler
% proprio (mais especifico) e ganha por especificidade.
:- http_handler('/matches/', handler, [method(get), prefix]).

handler(Request) :-
    memberchk(path(Path), Request),
    handle_path(Path, Request).

handle_path(Path, Request) :-
    extract_id(Path, Id),
    !,
    load_and_render(Request, Id).
handle_path(_, Request) :-
    http_redirect(see_other, '/matches', Request).

extract_id(Path, Id) :-
    atom_concat('/matches/', Id, Path),
    Id \== '',
    Id \== new,
    \+ sub_atom(Id, _, _, _, '/').

% Resolucao da partida (dados + estado) vive no service; aqui so escolhemos a
% pagina. A pagina nao atualiza sozinha; o usuario recarrega pelo link "Atualizar".
load_and_render(Request, Id) :-
    matches:match_detail(Id, Outcome),
    render_outcome(Outcome, Request).

render_outcome(done(Match), Request) :-
    !,
    render_done(Request, Match).
render_outcome(progress(Match, Status, Elapsed), Request) :-
    !,
    render_progress(Request, Match, Status, Elapsed).
render_outcome(not_found, Request) :-
    render_not_found(Request).

render_done(Request, Match) :-
    matches:agent_display_name(Match.thief_agent_id, ThiefName),
    matches:agent_display_name(Match.detective_agent_id, DetectiveName),
    matches:decode_replay(Match.replay_json, Replay),
    render_detail(Request, Match, ThiefName, DetectiveName, Replay).

replay_field(Replay, Key, _Default, Value) :-
    get_dict(Key, Replay, Value),
    !.
replay_field(_Replay, _Key, Default, Default).

% Resposta (HTML)
render_detail(Request, Match, ThiefName, DetectiveName, Replay) :-
    replay_field(Replay, turns, [], Turns),
    replay_field(Replay, events, [], Events),
    replay_field(Replay, setup, _{}, Setup),
    page_section:back_link('/matches', 'Voltar para partidas', BackLink),
    stat_card('Ladrão', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    winner_card(Match.winner, WinnerCard),
    setup_section(Setup, SetupHtml),
    events_section(Events, EventsHtml),
    turns_table(Turns, TableHtml),
    atom_concat('/map/', Match.id, MapLink),
    button_link:button_link(MapLink, 'Visualizar mapa', MapButton),
    page:reply_page(Request, 'Detalhe da partida', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Detalhe da partida'),
        p([class('font-mono text-xs text-surface-500 mb-5 break-all')], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-6')], [
            ThiefCard, DetectiveCard, WinnerCard
        ]),
        div([class('mb-8')], [MapButton]),
        SetupHtml,
        EventsHtml,
        h2([class('font-semibold mb-3')], 'Replay turno a turno'),
        TableHtml
    ]).

% =============================
% Pagina de partida em andamento / falha
% =============================

% Painel para partidas nao concluidas (fila/execucao) ou que falharam
% (timeout/erro). Nao recarrega sozinha: ha um link "Atualizar".
render_progress(Request, Match, Status, Elapsed) :-
    matches:agent_display_name(Match.thief_agent_id, ThiefName),
    matches:agent_display_name(Match.detective_agent_id, DetectiveName),
    elapsed_text(Elapsed, ElapsedText),
    status_banner(Status, Banner),
    page_section:back_link('/matches', 'Voltar para partidas', BackLink),
    stat_card('Ladrão', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    stat_card('Tempo decorrido', ElapsedText, TimeCard),
    atom_concat('/matches/', Match.id, SelfLink),
    ui:link_class('text-sm', RefreshClass),
    page:reply_page(Request, 'Partida em andamento', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Partida em andamento'),
        p([class('font-mono text-xs text-surface-500 mb-5 break-all')], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-8')], [
            ThiefCard, DetectiveCard, TimeCard
        ]),
        Banner,
        div([class('mt-4')], [
            a([href(SelfLink), class(RefreshClass)],
              'Atualizar')
        ])
    ]).

elapsed_text(Elapsed, Text) :-
    number(Elapsed),
    !,
    format(string(Text), "~w s", [Elapsed]).
elapsed_text(_Elapsed, "-").

status_banner(Status, Html) :-
    status_meta(Status, Title, Hint, Class),
    Html = div([class(Class)], [
        p([class('font-semibold')], Title),
        p([class('text-sm opacity-80 mt-1')], Hint)
    ]).

status_meta("queued", 'Na fila',
    'Aguardando um worker disponível para iniciar a execução.',
    'rounded-xl bg-amber-950 p-4 border border-amber-800 text-amber-200') :- !.
status_meta("running", 'Em execução',
    'A engine está processando esta partida.',
    'rounded-xl bg-sky-950 p-4 border border-sky-800 text-sky-200') :- !.
status_meta("timeout", 'Tempo esgotado',
    'A partida excedeu o limite de tempo e foi interrompida.',
    'rounded-xl bg-rose-950 p-4 border border-rose-800 text-rose-200') :- !.
status_meta("error", 'Falha na execução',
    'Ocorreu um erro ao executar esta partida.',
    'rounded-xl bg-rose-950 p-4 border border-rose-800 text-rose-200') :- !.
status_meta(_Other, 'Status desconhecido',
    'O estado desta partida não pode ser determinado.',
    'rounded-xl bg-surface-900 p-4 border border-surface-700 text-surface-200').
