:- module(agent_card, [
    agent_card/3,
    role_label/2
]).

:- use_module(ui).

% `CurrentUser` e o usuario logado (dict) ou o atomo `anon`; o dono ganha um
% botao de exclusao (ver actions/3).
agent_card(Agent, CurrentUser, Html) :-
    Name = Agent.name,
    role_label(Agent.role, RoleLabel),
    owner_link(Agent, OwnerHtml),
    privacy_badge(Agent, PrivacyHtml),
    actions(Agent, CurrentUser, ActionsHtml),
    format(atom(DomId), 'agent-card-~w', [Agent.id]),
    ui:surface_class('p-4', CardClass),
    Html = div([id(DomId), class(CardClass)], [
        div([class('flex items-start justify-between gap-3')], [
            div([class('min-w-0 flex-1')], [
                h2([class('font-bold text-lg break-words')], Name),
                OwnerHtml
            ]),
            div([class('flex shrink-0 flex-wrap justify-end gap-2')], [
                PrivacyHtml,
                span([class('rounded-full bg-surface-800 text-surface-300 text-xs px-2.5 py-1')],
                     RoleLabel)
            ])
        ]),
        p([class('text-surface-500 text-xs mt-3 font-mono break-all')], ['id: ', Agent.id]),
        ActionsHtml
    ]).

owner_link(Agent, Html) :-
    OwnerId = Agent.owner_user_id,
    owner_label(Agent, Label),
    format(atom(Href), '/users/~w', [OwnerId]),
    ui:link_class('break-all', LinkClass),
    Html = p([class('text-surface-400 text-xs mt-1')], [
        'por ',
        a([href(Href), class(LinkClass)], Label)
    ]).

owner_label(Agent, Email) :-
    get_dict(owner_email, Agent, Email),
    Email \== "",
    !.
owner_label(Agent, Label) :-
    Label = Agent.owner_user_id.

privacy_badge(Agent, Html) :-
    get_dict(is_private, Agent, true),
    !,
    Html = span([class('rounded-full bg-surface-950 text-surface-400 text-xs px-2.5 py-1 border border-surface-800')],
                'Privado').
privacy_badge(_, '').

% Botao de excluir para o dono ou para admin. Sem htmx: um onclick chama a rota
% do servidor via fetch e remove o cartao do DOM no sucesso.
actions(_Agent, anon, '') :- !.
actions(Agent, CurrentUser, Html) :-
    can_delete(CurrentUser, Agent),
    !,
    delete_onclick(Agent.id, OnClick),
    Html = div([class('mt-4 flex justify-end')], [
        button([
            type(button),
            onclick(OnClick),
            class('rounded-lg bg-red-950 px-3 py-1.5 text-xs font-semibold \c
                   text-red-200 border border-red-900 hover:bg-red-900 \c
                   hover:border-red-700 focus:outline-none focus:ring-2 \c
                   focus:ring-red-500/40')
        ], 'Excluir')
    ]).
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

role_label(thief, 'Ladrao') :- !.
role_label("thief", 'Ladrao') :- !.
role_label(detective, 'Detetive') :- !.
role_label("detective", 'Detetive') :- !.
role_label(Other, Other).
