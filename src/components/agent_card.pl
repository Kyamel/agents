:- module(agent_card, [
    agent_card/2,
    role_label/2
]).

%!  agent_card(+Agent, -Html) is det.
%
%   Renderiza o cartao HTML de um agente cadastrado.
agent_card(Agent, Html) :-
    Name = Agent.name,
    role_label(Agent.role, RoleLabel),
    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        div([class('flex items-center justify-between gap-3')], [
            h2([class('font-bold text-lg')], Name),
            span([class('rounded-full bg-slate-800 text-slate-300 text-xs px-2.5 py-1')],
                 RoleLabel)
        ]),
        p([class('text-slate-500 text-xs mt-3 font-mono break-all')], ['id: ', Agent.id]),
        p([class('text-slate-500 text-xs font-mono break-all')],
          ['modulo: ', Agent.module, ' | predicado: ', Agent.entry_predicate])
    ]).

%!  role_label(+Role, -Label) is det.
%
%   Traduz o papel de um agente para exibicao na interface.
role_label(thief, 'Ladrao') :- !.
role_label("thief", 'Ladrao') :- !.
role_label(detective, 'Detetive') :- !.
role_label("detective", 'Detetive') :- !.
role_label(Other, Other).
