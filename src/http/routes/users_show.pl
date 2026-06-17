:- module(route_users_show, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../db/db').
:- use_module('../../components/page').
:- use_module('../../components/ui').

% Prefix em /users/ para capturar /users/<id>. Nao existe /users (lista).
:- http_handler('/users/', handler, [method(get), prefix]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(path(Path), Request),
    extract_id(Path, Id),
    !,
    load_and_render(Request, Id).
handler(Request) :-
    render_not_found(Request).

extract_id(Path, Id) :-
    atom_concat('/users/', Id, Path),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_and_render(Request, Id) :-
    db:find_user_by_id(Id, User),
    !,
    load_profile(User, Profile),
    render_profile(Request, User, Profile).
load_and_render(Request, _) :-
    render_not_found(Request).

load_profile(User, Profile) :-
    db:list_agents(AllAgents),
    include(owner_is(User.id), AllAgents, Agents),
    db:list_matches(Matches),
    maplist(agent_profile(Matches), Agents, AgentProfiles),
    aggregate_stats(AgentProfiles, GlobalStats),
    Profile = _{
        agents: AgentProfiles,
        stats: GlobalStats
    }.

owner_is(UserId, Agent) :-
    same_id(UserId, Agent.owner_user_id).

agent_profile(Matches, Agent, Profile) :-
    agent_stats(Agent.id, Matches, Stats),
    Profile = _{
        agent: Agent,
        stats: Stats
    }.

agent_stats(AgentId, Matches, Stats) :-
    empty_stats(Initial),
    foldl(count_agent_match(AgentId), Matches, Initial, Stats).

count_agent_match(AgentId, Match, Stats0, Stats) :-
    match_result_for_agent(AgentId, Match, Result),
    !,
    increment_stat(Result, Stats0, Stats).
count_agent_match(_, _, Stats, Stats).

match_result_for_agent(AgentId, Match, Result) :-
    completed_match(Match),
    agent_role_in_match(AgentId, Match, Role),
    result_for_role(Role, Match.winner, Result).

completed_match(Match) :-
    Match.status == "done",
    Match.winner \== "",
    Match.winner \== '$null$'.

agent_role_in_match(AgentId, Match, thief) :-
    same_id(AgentId, Match.thief_agent_id),
    !.
agent_role_in_match(AgentId, Match, detective) :-
    same_id(AgentId, Match.detective_agent_id).

result_for_role(_, Winner, draw) :-
    same_text(Winner, "draw"),
    !.
result_for_role(Role, Winner, win) :-
    role_winner(Role, Winner),
    !.
result_for_role(_, _, loss).

role_winner(thief, Winner) :- same_text(Winner, "thief").
role_winner(detective, Winner) :- same_text(Winner, "detective").

aggregate_stats(AgentProfiles, Stats) :-
    empty_stats(Initial),
    foldl(add_agent_stats, AgentProfiles, Initial, Stats).

add_agent_stats(Profile, Stats0, Stats) :-
    add_stats(Stats0, Profile.stats, Stats).

empty_stats(_{wins:0, losses:0, draws:0}).

increment_stat(win, Stats0, Stats) :-
    Wins is Stats0.wins + 1,
    Stats = Stats0.put(wins, Wins).
increment_stat(loss, Stats0, Stats) :-
    Losses is Stats0.losses + 1,
    Stats = Stats0.put(losses, Losses).
increment_stat(draw, Stats0, Stats) :-
    Draws is Stats0.draws + 1,
    Stats = Stats0.put(draws, Draws).

add_stats(A, B, _{
    wins: Wins,
    losses: Losses,
    draws: Draws
}) :-
    Wins is A.wins + B.wins,
    Losses is A.losses + B.losses,
    Draws is A.draws + B.draws.

same_id(A, B) :-
    normalize_text(A, Text),
    normalize_text(B, Text).

same_text(A, B) :-
    normalize_text(A, Text),
    normalize_text(B, Text).

normalize_text(Value, Text) :-
    string(Value),
    !,
    Text = Value.
normalize_text(Value, Text) :-
    atom(Value),
    !,
    atom_string(Value, Text).
normalize_text(Value, Text) :-
    format(string(Text), "~w", [Value]).

% =============================
% Resposta (HTML)
% =============================

render_profile(Request, User, Profile) :-
    stats_summary(Profile.stats, Summary),
    agents_section(Profile.agents, AgentsSection),
    ui:link_class('text-sm', BackClass),
    page:reply_page(Request, 'Perfil', [
        a([href('/agents'), class(BackClass)],
          'Voltar para agentes'),
        h1([class('text-2xl font-bold mt-3 mb-1')], User.username),
        p([class('text-surface-400 text-sm mb-1 break-all')], User.email),
        p([class('font-mono text-xs text-surface-500 mb-5 break-all')], User.id),
        Summary,
        h2([class('text-xl font-bold mt-8 mb-4')], 'Agentes enviados'),
        AgentsSection
    ]).

stats_summary(Stats, Html) :-
    stat_card('Vitorias', Stats.wins, 'text-emerald-300', WinsCard),
    stat_card('Derrotas', Stats.losses, 'text-red-300', LossesCard),
    stat_card('Empates', Stats.draws, 'text-surface-300', DrawsCard),
    Html = div([class('grid sm:grid-cols-3 gap-4')], [
        WinsCard,
        LossesCard,
        DrawsCard
    ]).

stat_card(Label, Value, ValueClass, Html) :-
    atomic_list_concat(['text-3xl font-bold mt-1 ', ValueClass], Class),
    ui:surface_class('p-4', CardClass),
    Html = div([class(CardClass)], [
        p([class('text-xs uppercase tracking-wide text-surface-500')], Label),
        p([class(Class)], Value)
    ]).

agents_section([], Html) :-
    !,
    Html = div([class('rounded-xl border border-dashed border-surface-800 p-6 text-center text-surface-500')],
               'Nenhum agente enviado ainda.').
agents_section(AgentProfiles, Html) :-
    maplist(agent_stats_card, AgentProfiles, Cards),
    Html = div([class('grid sm:grid-cols-2 gap-4')], Cards).

agent_stats_card(Profile, Html) :-
    Agent = Profile.agent,
    Stats = Profile.stats,
    role_label(Agent.role, RoleLabel),
    mini_stat('V', Stats.wins, 'text-emerald-300', WinsStat),
    mini_stat('D', Stats.losses, 'text-red-300', LossesStat),
    mini_stat('E', Stats.draws, 'text-surface-300', DrawsStat),
    ui:surface_class('p-4', CardClass),
    Html = div([class(CardClass)], [
        div([class('flex items-start justify-between gap-3')], [
            div([class('min-w-0 flex-1')], [
                h3([class('font-bold text-lg break-words')], Agent.name),
                p([class('text-surface-500 text-xs font-mono break-all')], Agent.id)
            ]),
            span([class('rounded-full bg-surface-800 text-surface-300 text-xs px-2.5 py-1 shrink-0')],
                 RoleLabel)
        ]),
        div([class('grid grid-cols-3 gap-2 mt-4 text-center')], [
            WinsStat,
            LossesStat,
            DrawsStat
        ])
    ]).

mini_stat(Label, Value, ValueClass, Html) :-
    atomic_list_concat(['text-lg font-bold ', ValueClass], Class),
    Html = div([class('rounded-lg bg-surface-950 border border-surface-800 px-2 py-2')], [
        p([class('text-[11px] font-semibold text-surface-500')], Label),
        p([class(Class)], Value)
    ]).

role_label(thief, 'Ladrao') :- !.
role_label("thief", 'Ladrao') :- !.
role_label(detective, 'Detetive') :- !.
role_label("detective", 'Detetive') :- !.
role_label(Other, Other).

render_not_found(Request) :-
    ui:link_class(LinkClass),
    page:reply_page(Request, 'Usuario nao encontrado', [
        h1([class('text-2xl font-bold mb-2')], 'Usuario nao encontrado'),
        a([href('/agents'), class(LinkClass)],
          'Voltar para agentes')
    ]).
