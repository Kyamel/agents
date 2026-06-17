:- module(agent_card, [
    agent_card/3,
    role_label/2
]).

% `CurrentUser` e o usuario logado (dict) ou o atomo `anon`; o dono ganha um
% botao de exclusao (ver actions/3).
agent_card(Agent, CurrentUser, Html) :-
    Name = Agent.name,
    role_label(Agent.role, RoleLabel),
    owner_link(Agent, OwnerHtml),
    actions(Agent, CurrentUser, ActionsHtml),
    format(atom(DomId), 'agent-card-~w', [Agent.id]),
    Html = div([id(DomId),
                class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        div([class('flex items-start justify-between gap-3')], [
            div([class('min-w-0 flex-1')], [
                h2([class('font-bold text-lg break-words')], Name),
                OwnerHtml
            ]),
            span([class('rounded-full bg-slate-800 text-slate-300 text-xs px-2.5 py-1 shrink-0')],
                 RoleLabel)
        ]),
        p([class('text-slate-500 text-xs mt-3 font-mono break-all')], ['id: ', Agent.id]),
        ActionsHtml
    ]).

owner_link(Agent, Html) :-
    OwnerId = Agent.owner_user_id,
    owner_label(Agent, Label),
    format(atom(Href), '/users/~w', [OwnerId]),
    Html = p([class('text-slate-400 text-xs mt-1')], [
        'por ',
        a([href(Href),
           class('text-ufop-400 hover:underline break-all')], Label)
    ]).

owner_label(Agent, Email) :-
    get_dict(owner_email, Agent, Email),
    Email \== "",
    !.
owner_label(Agent, Label) :-
    Label = Agent.owner_user_id.

% Botao de excluir so para o dono; htmx troca o cartao por vazio no sucesso.
actions(_Agent, anon, '') :- !.
actions(Agent, CurrentUser, Html) :-
    is_owner(CurrentUser, Agent),
    !,
    format(atom(DeleteUrl), '/agents/~w', [Agent.id]),
    format(atom(TargetSel), '#agent-card-~w', [Agent.id]),
    Html = div([class('mt-4 flex justify-end')], [
        button([
            type(button),
            'hx-delete'(DeleteUrl),
            'hx-confirm'('Excluir esse agente? As partidas ja jogadas continuam disponiveis.'),
            'hx-target'(TargetSel),
            'hx-swap'('outerHTML'),
            class('rounded-lg bg-red-950 px-3 py-1.5 text-xs font-semibold \c
                   text-red-200 border border-red-900 hover:bg-red-900 \c
                   hover:border-red-700 focus:outline-none focus:ring-2 \c
                   focus:ring-red-500/40')
        ], 'Excluir')
    ]).
actions(_, _, '').

is_owner(User, Agent) :-
    is_dict(User),
    normalize_id(User.id, UserIdN),
    normalize_id(Agent.owner_user_id, OwnerIdN),
    UserIdN == OwnerIdN.

normalize_id(X, S) :- atom(X), !, atom_string(X, S).
normalize_id(X, X) :- string(X), !.
normalize_id(X, S) :- term_string(X, S).

role_label(thief, 'Ladrao') :- !.
role_label("thief", 'Ladrao') :- !.
role_label(detective, 'Detetive') :- !.
role_label("detective", 'Detetive') :- !.
role_label(Other, Other).
