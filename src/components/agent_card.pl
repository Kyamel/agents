:- module(agent_card, [

  ]).

agent_card(Agent, Html) :-
    Name = Agent.name,
    Kind = Agent.kind,

    Html = div([class('rounded-xl bg-slate-900 p-4 border border-slate-800')], [
        h2([class('font-bold text-lg')], Name),
        p([class('text-slate-400')], Kind),
        div([class('mt-4 flex gap-2')], [
            a(
                [
                    href('/agents'),
                    class('rounded-lg bg-slate-800 px-3 py-1 text-sm hover:bg-slate-700')
                ],
                'Detalhes'
            )
        ])
    ]).
