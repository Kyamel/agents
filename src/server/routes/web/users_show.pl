:- module(route_users_show, []).

:- use_module(library(apply)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module('../../../services/users').
:- use_module('../../views/page').
:- use_module('../../views/page_section').
:- use_module('../../views/pagination').
:- use_module('../../views/agent_card').
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
    ui:text_class(title, 'mt-3 mb-2', TitleClass),
    %ui:text_class(meta, 'font-mono text-surface-500 mb-6 break-all', IdClass),
    ui:text_class(section, 'mt-8 mb-4', SectionTitleClass),
    page:reply_page(Request, 'Perfil', [
        BackLink,
        h1([class(TitleClass)], User.username),
        %p([class(IdClass)], ['Id ', User.id]),
        Summary,
        h2([class(SectionTitleClass)], 'Agentes enviados'),
        AgentsSection,
        PaginationNav
    ]).

% Retrospecto global nos mesmos cards do resto do app (surface + eyebrow), com
% cor so no numero: vitoria verde, derrota vermelho, empate neutro.
stats_summary(Stats, Html) :-
    stat_card('Vitórias', Stats.wins, 'text-emerald-300', WinsCard),
    stat_card('Derrotas', Stats.losses, 'text-ufop-400', LossesCard),
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
    maplist(agent_profile_card, AgentProfiles, Cards),
    Html = div([class('grid sm:grid-cols-2 gap-3')], Cards).

agent_profile_card(Profile, Html) :-
    put_dict(stats, Profile.agent, Profile.stats, AgentWithStats),
    agent_card:agent_card(AgentWithStats, anon, Html).

render_not_found(Request) :-
    ui:link_class(LinkClass),
    ui:text_class(title, 'mb-2', TitleClass),
    page:reply_page(Request, 'Usuário não encontrado', [
        h1([class(TitleClass)], 'Usuário não encontrado'),
        a([href('/agents'), class(LinkClass)],
          'Voltar para agentes')
    ]).
