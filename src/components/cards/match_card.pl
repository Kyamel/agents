:- module(match_card, [
    match_card/2,
    winner_label/3
]).

%!  match_card(+Match, -Html) is det.
%
%   Renderiza o cartao clicavel de uma partida, com link para o detalhe.
match_card(Match, Html) :-
    Id = Match.id,
    atom_concat('/matches/', Id, Href),
    winner_label(Match.winner, WinnerText, BadgeClass),
    Html = a([ href(Href),
               class('block rounded-xl bg-slate-900 p-4 border border-slate-800 hover:border-slate-600 transition')
             ], [
        div([class('flex items-center justify-between gap-3')], [
            span([class('font-mono text-xs text-slate-500 break-all')], Id),
            span([class(BadgeClass)], WinnerText)
        ]),
        p([class('text-slate-400 text-sm mt-3 font-mono break-all')],
          ['Ladrao: ', Match.thief_agent_id]),
        p([class('text-slate-400 text-sm font-mono break-all')],
          ['Detetive: ', Match.detective_agent_id]),
        p([class('text-slate-600 text-xs mt-2')], ['Criada em ', Match.created_at])
    ]).

%!  winner_label(+Winner, -Text, -BadgeClass) is det.
%
%   Mapeia o vencedor de uma partida para rotulo e classe de destaque.
winner_label(thief, 'Vitoria do ladrao', Class) :- !, badge_class(amber, Class).
winner_label("thief", 'Vitoria do ladrao', Class) :- !, badge_class(amber, Class).
winner_label(detective, 'Vitoria do detetive', Class) :- !, badge_class(emerald, Class).
winner_label("detective", 'Vitoria do detetive', Class) :- !, badge_class(emerald, Class).
winner_label(_, 'Empate', Class) :- badge_class(slate, Class).

%!  badge_class(+Tone, -Class) is det.
%
%   Resolve as classes Tailwind para a etiqueta de resultado.
badge_class(amber,
    'rounded-full bg-amber-950 text-amber-300 text-xs px-2.5 py-1 whitespace-nowrap').
badge_class(emerald,
    'rounded-full bg-emerald-950 text-emerald-300 text-xs px-2.5 py-1 whitespace-nowrap').
badge_class(slate,
    'rounded-full bg-slate-800 text-slate-300 text-xs px-2.5 py-1 whitespace-nowrap').
