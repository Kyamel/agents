:- module(route_matches_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../../services/matches').
:- use_module('../../views/page').
:- use_module('../../views/match_card').
:- use_module('../../views/match_detail').
:- use_module('../../views/match_map_data').
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
    replay_field(Replay, setup, _{}, Setup),
    match_map_data:map_data(Match.scenario, Replay, MapData),
    get_dict(frames, MapData, Frames),
    match_map_data:frame_events(Frames, Events),
    page_section:back_link('/matches', 'Voltar para partidas', BackLink),
    stat_card('Ladrão', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    winner_card(Match.winner, WinnerCard),
    setup_section(Setup, SetupHtml),
    events_section(Events, EventsHtml),
    turns_table(Turns, TableHtml),
    atom_concat('/map/', Match.id, MapLink),
    button_link:button_link(MapLink, 'Visualizar mapa', MapButton),
    page_section:top_bar('Detalhe da partida', MapButton, TopBar),
    %ui:text_class(meta, 'font-mono text-surface-500 mb-5 break-all', IdClass),
    ui:text_class(emphasis, 'mt-3 mb-2', ReplayTitleClass),
    page:reply_page(Request, 'Detalhe da partida', [
        BackLink,
        TopBar,
        %p([class(IdClass)], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-6')], [
            ThiefCard, DetectiveCard, WinnerCard
        ]),
        SetupHtml,
        EventsHtml,
        h2([class(ReplayTitleClass)], 'Replay turno a turno'),
        TableHtml
    ]).


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
    ui:text_class(meta, AuxiliaryClass),
    ui:link_class(AuxiliaryClass, RefreshClass),
    ui:text_class(title, 'mt-3 mb-1', TitleClass),
    ui:text_class(meta, 'font-mono text-surface-500 mb-5 break-all', IdClass),
    page:reply_page(Request, 'Partida em andamento', [
        BackLink,
        h1([class(TitleClass)], 'Partida em andamento'),
        p([class(IdClass)], Match.id),
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
    status_meta(Status, Title, Hint, Accent),
    ui:tinted_card_class(Accent, Class),
    ui:text_class(meta, 'opacity-80 mt-1', HintClass),
    Html = div([class(Class)], [
        p([class('font-semibold')], Title),
        p([class(HintClass)], Hint)
    ]).

status_meta("queued", 'Na fila',
    'Aguardando um worker disponível para iniciar a execução.', amber) :- !.
status_meta("running", 'Em execução',
    'A engine está processando esta partida.', emerald) :- !.
status_meta("timeout", 'Tempo esgotado',
    'A partida excedeu o limite de tempo e foi interrompida.', rose) :- !.
status_meta("error", 'Falha na execução',
    'Ocorreu um erro ao executar esta partida.', rose) :- !.
status_meta(_Other, 'Status desconhecido',
    'O estado desta partida não pode ser determinado.', neutral).
