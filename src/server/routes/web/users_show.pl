:- module(route_users_show, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module('../../../services/users').
:- use_module('../../views/page').
:- use_module('../../views/page_section').
:- use_module('../../views/pagination').
:- use_module('../../views/ui').
:- use_module('../../views/match_detail', [stat_card/3, stat_card/4]).

% Prefix em /users/ para capturar /users/<id>. Nao existe /users (lista).
:- http_handler('/users/', handler, [method(get), prefix]).

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

load_and_render(Request, Id) :-
    http_parameters(Request, [page(Page0, [integer, default(1)])]),
    Page is max(1, Page0),
    users:profile_page(Id, Page, 10, Outcome),
    render_outcome(Outcome, Id, Request).

render_outcome(profile(User, AgentStats, GlobalStats, Pagination), Id, Request) :-
    !,
    maplist(to_agent_profile, AgentStats, AgentProfiles),
    render_profile(Request, Id, User,
                   _{agents: AgentProfiles, stats: GlobalStats, pagination: Pagination}).
render_outcome(not_found, _Id, Request) :-
    render_not_found(Request).

to_agent_profile(stat(Agent, Stats), _{agent: Agent, stats: Stats}).

% Resposta (HTML)
render_profile(Request, Id, User, Profile) :-
    page_section:back_link('/agents', 'Voltar para agentes', BackLink),
    stats_summary(Profile.stats, Summary),
    agents_section(Profile.agents, AgentsSection),
    format(atom(BaseUrl), '/users/~w', [Id]),
    pagination:pagination_nav(BaseUrl, Profile.pagination, PaginationNav),
    page:reply_page(Request, 'Perfil', [
        BackLink,
        h1([class('text-2xl font-bold mt-3 mb-1')], User.username),
        p([class('text-surface-400 text-sm mb-1 break-all')], User.email),
        p([class('font-mono text-xs text-surface-500 mb-6 break-all')], User.id),
        Summary,
        h2([class('text-xl font-bold mt-8 mb-4')], 'Agentes enviados'),
        AgentsSection,
        PaginationNav
    ]).

% Retrospecto global nos mesmos cards do resto do app (surface + eyebrow), com
% cor so no numero: vitoria verde, derrota vermelho, empate neutro.
stats_summary(Stats, Html) :-
    stat_card('Vitórias', Stats.wins, 'text-emerald-300', WinsCard),
    stat_card('Derrotas', Stats.losses, 'text-red-300', LossesCard),
    stat_card('Empates', Stats.draws, DrawsCard),
    Html = div([class('grid sm:grid-cols-3 gap-4')], [
        WinsCard,
        LossesCard,
        DrawsCard
    ]).

agents_section([], Html) :-
    !,
    page_section:empty_state('Nenhum agente enviado ainda.', Html).
agents_section(AgentProfiles, Html) :-
    maplist(agent_stats_card, AgentProfiles, Cards),
    Html = div([class('grid sm:grid-cols-2 gap-4')], Cards).

% Mesmo esqueleto do agent_card (nome + id + pill de papel); o retrospecto vira
% uma linha discreta em vez de caixas aninhadas.
agent_stats_card(Profile, Html) :-
    Agent = Profile.agent,
    role_label(Agent.role, RoleLabel),
    record_line(Profile.stats, RecordLine),
    ui:surface_class('p-4', CardClass),
    Html = div([class(CardClass)], [
        div([class('flex items-start justify-between gap-3')], [
            div([class('min-w-0 flex-1')], [
                h3([class('font-bold text-lg break-words')], Agent.name),
                p([class('text-surface-500 text-xs mt-1 font-mono break-all')],
                  ['id: ', Agent.id])
            ]),
            span([class('rounded-full bg-surface-800 text-surface-300 text-xs px-2.5 py-1 shrink-0')],
                 RoleLabel)
        ]),
        p([class('text-surface-400 text-sm mt-3')], RecordLine)
    ]).

% Retrospecto colorido (numero destacado, letra discreta): vitoria verde,
% derrota vermelho, empate neutro — como o resumo global.
record_line(Stats, [W, Sep, L, Sep, D]) :-
    Sep = span([class('text-surface-600')], ' - '),
    stat_part(Stats.wins,   'V', 'text-emerald-300', W),
    stat_part(Stats.losses, 'D', 'text-red-300',     L),
    stat_part(Stats.draws,  'E', 'text-surface-300', D).

stat_part(Value, Label, ColorClass, span([], [
        span([class(NumClass)], Value),
        span([class('text-surface-500')], LabelText)
    ])) :-
    atomic_list_concat([ColorClass, 'font-semibold'], ' ', NumClass),
    atom_concat(' ', Label, LabelText).

role_label(thief, 'Ladrão') :- !.
role_label("thief", 'Ladrão') :- !.
role_label(detective, 'Detetive') :- !.
role_label("detective", 'Detetive') :- !.
role_label(Other, Other).

render_not_found(Request) :-
    ui:link_class(LinkClass),
    page:reply_page(Request, 'Usuário não encontrado', [
        h1([class('text-2xl font-bold mb-2')], 'Usuário não encontrado'),
        a([href('/agents'), class(LinkClass)],
          'Voltar para agentes')
    ]).
