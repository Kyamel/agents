:- module(app_agents, [
    agents_page/1
  ]).

:- use_module(library(http/html_write)).
:- use_module('../../store').
:- use_module('../../components/page').

agents_page(_Request) :-
    Title = 'Agents',
    store:list_agents(Agents),
    agents_list(Agents, AgentsHtml),

    page:layout(Title, [
        h1([class('text-2xl font-bold mb-4')], 'Agentes'),
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

create_agent_form(Html) :-
    Html = form([action('/agents/create'), method('POST')], [
        button(
            [
                type(submit),
                class('rounded-xl bg-green-600 px-4 py-2 text-white font-semibold hover:bg-green-500')
            ],
            'Criar agente'
        )
    ]).

create_agent_action(_Request) :-
    % Aqui você chamaria sua lógica:
    % store:save_agent(...)

    http_redirect(see_other, '/agents', _Request).

agents_list(Agents, Html) :-
    maplist(agent_card, Agents, Cards),
    Html = div([class('grid gap-4')], Cards).

agent_card(Agent, Html) :-
    Name = Agent.name,
    Role = Agent.role,

    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        h2([class('font-bold text-lg')], Name),
        p([class('text-slate-400')], Role)
    ]).
