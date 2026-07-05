:- module(route_agents_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../services/agents').
:- use_module('../../views/page').
:- use_module('../../views/page_section').
:- use_module('../../views/pagination').
:- use_module('../../views/card_list').
:- use_module('../../views/match_card').
:- use_module('../../views/match_detail', [stat_card/3, stat_card/4]).
:- use_module('../../views/agent_card',
              [role_label/2, role_badge_class/2]).
:- use_module('../../views/button_link').
:- use_module('../../views/ui').

% Prefix público para /agents/<id>; as rotas exatas /agents/new e
% /agents/<id>/delete continuam vencendo por especificidade no dispatcher.
:- http_handler('/agents/', handler, [method(get), prefix]).

handler(Request) :-
    memberchk(path(Path), Request),
    extract_id(Path, Id),
    !,
    http_parameters(Request, [page(Page0, [integer, default(1)])]),
    Page is max(1, Page0),
    agents:profile_page(Id, Page, 10, Outcome),
    render_outcome(Outcome, Request).
handler(Request) :-
    render_not_found(Request).

extract_id(Path, Id) :-
    atom_concat('/agents/', Id, Path),
    Id \== '',
    Id \== new,
    \+ sub_atom(Id, _, _, _, '/').

render_outcome(profile(Agent, Owner, Stats, Matches, Pagination),
               Request) :-
    !,
    render_profile(Request, Agent, Owner, Stats, Matches, Pagination).
render_outcome(not_found, Request) :-
    render_not_found(Request).

render_profile(Request, Agent, Owner, Stats, Matches, PaginationMeta) :-
    page_section:back_link('/agents', 'Voltar para agentes', BackLink),
    profile_heading(Agent, Owner, Heading),
    stats_summary(Stats, StatsSummary),
    card_list:card_grid(
        Matches,
        match_card:match_card,
        'grid sm:grid-cols-2 gap-4',
        'Este agente ainda não participou de nenhuma partida.',
        History
    ),
    format(atom(BaseUrl), '/agents/~w', [Agent.id]),
    pagination:pagination_nav(BaseUrl, PaginationMeta, Pagination),
    ui:text_class(section, 'mt-8 mb-4', SectionClass),
    format(string(Title), "Perfil de ~w", [Agent.name]),
    page:reply_page(Request, Title, [
        BackLink,
        Heading,
        StatsSummary,
        h2([class(SectionClass)], 'Histórico de partidas'),
        History,
        Pagination
    ]).

profile_heading(Agent, Owner, Html) :-
    role_label(Agent.role, RoleLabel),
    role_badge_class(Agent.role, RoleClass),
    lifecycle_badge(Agent.deleted_at, LifecycleBadge),
    source_button(Agent, SourceButton),
    ui:text_class(title, 'break-words', TitleClass),
    ui:text_class(meta, 'mt-2 text-surface-400', MetaClass),
    ui:link_class(OwnerLinkClass),
    format(atom(OwnerHref), '/users/~w', [Owner.id]),
    ui:local_time(Agent.created_at, CreatedTime),
    Html = div([class('mt-3 mb-6')], [
        div([
            class('flex flex-col items-start justify-between gap-3 sm:flex-row')
        ], [
            div([class('flex flex-wrap items-center gap-3')], [
                h1([class(TitleClass)], Agent.name),
                span([class(RoleClass)], RoleLabel),
                LifecycleBadge
            ]),
            SourceButton
        ]),
        p([class(MetaClass)], [
            'Enviado por ',
            a([href(OwnerHref), class(OwnerLinkClass)], Owner.username),
            ' em ',
            CreatedTime
        ])
    ]).

source_button(Agent, Html) :-
    get_dict(source, Agent, _),
    !,
    format(atom(Href), '/agents/~w/source', [Agent.id]),
    button_link:button_link(Href, 'Ver código-fonte', Html).
source_button(_Agent, '').

lifecycle_badge("", '') :- !.
lifecycle_badge(_DeletedAt, span([class(Class)], 'Excluído')) :-
    ui:pill_class(muted, Class).

stats_summary(Stats, Html) :-
    format(string(WinRate), "~1f%", [Stats.win_rate]),
    stat_card('Win rate', WinRate, 'text-emerald-300', RateCard),
    stat_card('Concluídas', Stats.total, TotalCard),
    stat_card('Vitórias', Stats.wins, 'text-emerald-300', WinsCard),
    stat_card('Derrotas', Stats.losses, 'text-ufop-400', LossesCard),
    stat_card('Empates', Stats.draws, DrawsCard),
    Html = div([
        class('grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5')
    ], [
        RateCard, TotalCard, WinsCard, LossesCard, DrawsCard
    ]).

render_not_found(Request) :-
    ui:link_class(LinkClass),
    ui:text_class(title, 'mb-2', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-6', TextClass),
    page:reply_page(Request, 'Agente não encontrado', [
        h1([class(TitleClass)], 'Agente não encontrado'),
        p([class(TextClass)],
          'Não existe agente com esse identificador.'),
        a([href('/agents'), class(LinkClass)], 'Voltar para agentes')
    ]).
