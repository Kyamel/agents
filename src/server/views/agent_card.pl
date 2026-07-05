:- module(agent_card, [
    agent_card/3,
    role_label/2,
    role_badge_class/2
]).

:- use_module(ui).
:- use_module(agent_link).

% `CurrentUser` e o usuario logado (dict) ou o atomo `anon`; o dono ganha um
% botao de exclusao (ver actions/3).
agent_card(Agent, CurrentUser, Html) :-
    Name = Agent.name,
    role_label(Agent.role, RoleLabel),
    owner_link(Agent, OwnerHtml),
    stats_line(Agent, StatsHtml),
    privacy_badge(Agent, PrivacyHtml),
    actions(Agent, CurrentUser, ActionsHtml),
    ui:text_class(emphasis, 'break-words', NameClass),
    role_badge_class(Agent.role, RoleBadgeClass),
    format(atom(DomId), 'agent-card-~w', [Agent.id]),
    ui:surface_class('px-3.5 py-3', CardClass),
    format(string(ProfileLabel), "~w #~w", [Name, Agent.id]),
    agent_link:agent_link(Agent.id, ProfileLabel, NameLink),
    Html = div([id(DomId), class(CardClass)], [
        div([class('flex items-start justify-between gap-2')], [
            div([class('min-w-0 flex-1')], [
                h2([class(NameClass)], NameLink)
            ]),
            div([class('flex shrink-0 flex-wrap justify-end gap-2')], [
                PrivacyHtml,
                span([class(RoleBadgeClass)],
                     RoleLabel)
            ])
        ]),
        div([class('mt-2')], [
            OwnerHtml,
            div([class('mt-1 flex items-center justify-between gap-3')], [
                StatsHtml,
                ActionsHtml
            ])
        ])
    ]).

owner_link(Agent, Html) :-
    get_dict(owner_name, Agent, _),
    !,
    OwnerId = Agent.owner_user_id,
    owner_label(Agent, Label),
    format(atom(Href), '/users/~w', [OwnerId]),
    ui:link_class('break-all', LinkClass),
    ui:text_class(meta, 'min-w-0 text-surface-400', OwnerClass),
    Html = p([class(OwnerClass)], [
        'por ',
        a([href(Href), class(LinkClass)], Label)
    ]).
owner_link(_Agent, '').

owner_label(Agent, Name) :-
    get_dict(owner_name, Agent, Name),
    Name \== "",
    !.
owner_label(Agent, Label) :-
    Label = Agent.owner_user_id.

stats_line(Agent, Html) :-
    get_dict(stats, Agent, Stats),
    !,
    record_line(Stats, RecordLine),
    ui:text_class(normal, 'text-surface-400', Class),
    Html = p([class(Class)], RecordLine).
stats_line(_Agent, '').

record_line(Stats, [W, Sep, L, Sep, D]) :-
    Sep = span([class('text-surface-500')], ' - '),
    stat_part(Stats.wins,   'V', 'text-emerald-300', W),
    stat_part(Stats.losses, 'D', 'text-ufop-400',     L),
    stat_part(Stats.draws,  'E', 'text-surface-300', D).

stat_part(Value, Label, ColorClass, span([], [
        span([class(NumClass)], Value),
        span([class('text-surface-500')], LabelText)
    ])) :-
    atomic_list_concat([ColorClass, 'font-semibold'], ' ', NumClass),
    atom_concat(' ', Label, LabelText).

privacy_badge(Agent, Html) :-
    get_dict(is_private, Agent, true),
    !,
    ui:pill_class(muted, Class),
    Html = span([class(Class)],
                'Privado').
privacy_badge(_, '').

% Botao de excluir para o dono ou para admin. Sem htmx: um onclick chama a rota
% do servidor via fetch e remove o cartao do DOM no sucesso.
actions(_Agent, anon, '') :- !.
actions(Agent, CurrentUser, Html) :-
    can_delete(CurrentUser, Agent),
    !,
    delete_onclick(Agent.id, OnClick),
    format(atom(DeleteLabel), 'Excluir agente ~w', [Agent.name]),
    ui:text_class(
        meta,
        'rounded-md bg-ufop-950 px-2.5 py-1 font-semibold text-ufop-200 \c
         border border-ufop-900 hover:bg-ufop-900 hover:border-ufop-700 \c
         focus:outline-none focus:ring-2 focus:ring-ufop-500/40',
        ButtonClass
    ),
    Html = button([
        type(button),
        onclick(OnClick),
        'aria-label'(DeleteLabel),
        class(ButtonClass)
    ], 'Excluir').
actions(_, _, '').

% JS inline: confirma, faz DELETE /agents/<id>/delete (cookie de sessao vai
% junto por padrao) e remove o cartão no sucesso.
delete_onclick(Id, OnClick) :-
    format(
        atom(OnClick),
        "if (confirm('Excluir este agente? As partidas já jogadas continuarão disponíveis.')) {\c
            fetch('/agents/~w/delete', { method: 'DELETE' })\c
                .then(function (response) {\c
                    if (response.ok) {\c
                        var card = document.getElementById('agent-card-~w');\c
                        if (card) {\c
                            card.remove();\c
                        }\c
                        var live = document.getElementById('app-live-region');\c
                        if (live) {\c
                            live.textContent = 'Agente excluído.';\c
                        }\c
                    } else {\c
                        alert('Não foi possível excluir o agente.');\c
                    }\c
                })\c
                .catch(function () {\c
                    alert('Erro de rede ao excluir.');\c
                });\c
        }",
        [Id, Id]
    ).

% Dono ou admin pode excluir (espelha a autorizacao da rota).
can_delete(User, Agent) :-
    is_owner(User, Agent),
    !.
can_delete(User, _Agent) :-
    is_admin_user(User).

is_owner(User, Agent) :-
    is_dict(User),
    normalize_id(User.id, UserIdN),
    normalize_id(Agent.owner_user_id, OwnerIdN),
    UserIdN == OwnerIdN.

is_admin_user(User) :-
    is_dict(User),
    get_dict(role, User, Role),
    normalize_id(Role, "admin").

normalize_id(X, S) :- atom(X), !, atom_string(X, S).
normalize_id(X, X) :- string(X), !.
normalize_id(X, S) :- term_string(X, S).

role_label("thief", 'Ladrão') :- !.
role_label("detective", 'Detetive') :- !.
role_label(Other, Other).

role_badge_class("thief", Class) :-
    !,
    ui:pill_class(amber, Class).
role_badge_class("detective", Class) :-
    !,
    ui:pill_class(sky, Class).
role_badge_class(_, Class) :-
    ui:pill_class(neutral, Class).
