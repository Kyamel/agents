:- module(route_matches_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/json)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../engine/match_queue').
:- use_module('../../engine/match_runner').
:- use_module('../../components/page').
:- use_module('../../components/match_card').
:- use_module('../../components/match_detail').
:- use_module('../../components/page_section').
:- use_module('../../components/button_link').

% Prefix em /matches/ para capturar /matches/<id>. /matches/new tem handler
% proprio (mais especifico) e ganha por especificidade.
:- http_handler('/matches/', handler, [method(get), prefix]).

% =============================
% Handler
% =============================

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

% =============================
% Logica (DB)
% =============================

load_and_render(Request, Id) :-
    sqlite_store:get_match(Id, Match),
    !,
    render_for_status(Request, Id, Match).
load_and_render(Request, _) :-
    render_not_found(Request).

% Partida concluida: replay completo. Caso contrario (na fila/executando/falha):
% painel de status. A pagina nao atualiza sozinha; o usuario recarrega quando
% quiser pelo link "Atualizar".
render_for_status(Request, _Id, Match) :-
    Match.status == "done",
    !,
    render_done(Request, Match).
render_for_status(Request, Id, Match) :-
    match_queue:job_info(Id, Info),
    !,
    render_progress(Request, Match, Info.status, Info.elapsed_seconds).
render_for_status(Request, _Id, Match) :-
    render_progress(Request, Match, Match.status, "-").

render_done(Request, Match) :-
    agent_display_name(Match.thief_agent_id, ThiefName),
    agent_display_name(Match.detective_agent_id, DetectiveName),
    replay_data(Match.replay_json, Replay),
    render_detail(Request, Match, ThiefName, DetectiveName, Replay).

agent_display_name(AgentId, Name) :-
    sqlite_store:get_agent(AgentId, Agent),
    !,
    Name = Agent.name.
agent_display_name(AgentId, AgentId).

%!  replay_data(+ReplayJson, -Replay) is det.
%
%   Decodifica o replay para o dict `{turns, events, setup, ...}`. Cai num
%   dict vazio se o JSON estiver ausente ou corrompido.
replay_data(ReplayJson, Replay) :-
    catch(atom_json_dict(ReplayJson, Replay, []), _, fail),
    is_dict(Replay),
    !.
replay_data(_, _{}).

%!  replay_field(+Replay, +Key, +Default, -Value) is det.
replay_field(Replay, Key, _Default, Value) :-
    get_dict(Key, Replay, Value),
    !.
replay_field(_Replay, _Key, Default, Default).

% =============================
% Resposta (HTML)
% =============================

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
        p([class('font-mono text-xs text-slate-500 mb-5 break-all')], Match.id),
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

%!  render_progress(+Request, +Match, +Status, +Elapsed) is det.
%
%   Painel para partidas que ainda nao concluiram (na fila/executando) ou que
%   falharam (timeout/erro). A pagina nao recarrega sozinha: ha um link
%   "Atualizar" para o usuario consultar o estado quando quiser.
render_progress(Request, Match, Status, Elapsed) :-
    agent_display_name(Match.thief_agent_id, ThiefName),
    agent_display_name(Match.detective_agent_id, DetectiveName),
    elapsed_text(Elapsed, ElapsedText),
    status_banner(Status, Banner),
    page_section:back_link('/matches', 'Voltar para partidas', BackLink),
    stat_card('Ladrao', ThiefName, ThiefCard),
    stat_card('Detetive', DetectiveName, DetectiveCard),
    stat_card('Tempo decorrido', ElapsedText, TimeCard),
    atom_concat('/matches/', Match.id, SelfLink),
    page:reply_page(Request, 'Partida em andamento', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], 'Partida em andamento'),
        p([class('font-mono text-xs text-slate-500 mb-5 break-all')], Match.id),
        div([class('grid sm:grid-cols-3 gap-4 mb-8')], [
            ThiefCard, DetectiveCard, TimeCard
        ]),
        Banner,
        div([class('mt-4')], [
            a([href(SelfLink), class('text-ufop-400 hover:underline text-sm')],
              'Atualizar')
        ])
    ]).

%!  elapsed_text(+Elapsed, -Text) is det.
elapsed_text(Elapsed, Text) :-
    number(Elapsed),
    !,
    format(string(Text), "~w s", [Elapsed]).
elapsed_text(_Elapsed, "-").

%!  status_banner(+Status, -Html) is det.
status_banner(Status, Html) :-
    status_meta(Status, Title, Hint, Class),
    Html = div([class(Class)], [
        p([class('font-semibold')], Title),
        p([class('text-sm opacity-80 mt-1')], Hint)
    ]).

status_meta("queued", 'Na fila',
    'Aguardando um worker disponivel para iniciar a execucao.',
    'rounded-xl bg-amber-950 p-4 border border-amber-800 text-amber-200') :- !.
status_meta("running", 'Em execucao',
    'A engine esta processando esta partida.',
    'rounded-xl bg-sky-950 p-4 border border-sky-800 text-sky-200') :- !.
status_meta("timeout", 'Tempo esgotado',
    'A partida excedeu o limite de tempo e foi interrompida.',
    'rounded-xl bg-rose-950 p-4 border border-rose-800 text-rose-200') :- !.
status_meta("error", 'Falha na execucao',
    'Ocorreu um erro ao executar esta partida.',
    'rounded-xl bg-rose-950 p-4 border border-rose-800 text-rose-200') :- !.
status_meta(_Other, 'Status desconhecido',
    'O estado desta partida nao pode ser determinado.',
    'rounded-xl bg-slate-900 p-4 border border-slate-700 text-slate-200').
