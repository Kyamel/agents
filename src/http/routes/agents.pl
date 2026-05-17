:- module(app_agents, [
    agents_page/1
  ]).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/page').

:- http_handler(root(agents), agents_page, [method(get)]).

%!  agents_page(+Request) is det.
%
%   Renderiza a página com a listagem de agentes cadastrados.
agents_page(_Request) :-
    Title = 'Agents',
    sqlite_store:list_agents(Agents),
    agents_list(Agents, AgentsHtml),
    page:layout(Title, [
        h1([class('text-2xl font-bold mb-4')], 'Agentes'),
        p([class('text-slate-400 mb-6')],
          'Lista dos agentes cadastrados via API em /api/v1/agents.'),
        AgentsHtml
      ],
      Page
    ),
    reply_html_page(
        [
            title(Title),
            script([src('https://cdn.tailwindcss.com')], [])
        ],
        Page
    ).

%!  agents_list(+Agents, -Html) is det.
%
%   Converte lista de agentes em estrutura HTML.
agents_list(Agents, Html) :-
    (   Agents == []
    ->  Html = p([class('text-slate-500')], 'Nenhum agente cadastrado ainda.')
    ;   maplist(agent_card, Agents, Cards),
        Html = div([class('grid gap-4')], Cards)
    ).

%!  agent_card(+Agent, -Html) is det.
%
%   Renderiza o cartão HTML de um agente.
agent_card(Agent, Html) :-
    Name = Agent.name,
    Role = Agent.role,
    Id = Agent.id,
    ModuleName = Agent.module,
    Entry = Agent.entry_predicate,
    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        h2([class('font-bold text-lg')], Name),
        p([class('text-slate-400')], Role),
        p([class('text-slate-500 text-sm mt-2')], ['ID: ', Id]),
        p([class('text-slate-500 text-sm')], ['Modulo: ', ModuleName]),
        p([class('text-slate-500 text-sm')], ['Predicado: ', Entry])
    ]).
