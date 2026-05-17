:- module(page, [
     layout/3
  ]).

%!  layout(+Title, +Body, -Page) is det.
%
%   Monta layout HTML base da aplicação com header, conteúdo e footer.
layout(Title, Body, Page) :-
    Page = [
        div([class('min-h-screen bg-slate-950 text-white flex flex-col')], [
            header([class('border-b border-slate-800 p-4')], [
                nav([class('flex gap-4')], [
                    a([href('/'), class('hover:underline')], 'Home'),
                    a([href('/agents-page'), class('hover:underline')], 'Agentes'),
                    a([href('/matches-page'), class('hover:underline')], 'Partidas')
                ])
            ]),

            main([class('flex-1 max-w-4xl mx-auto w-full p-6')], Body),

            footer([class('border-t border-slate-800 p-4 text-slate-400 text-sm')], [
                'Feito em Prolog'
            ])
        ])
    ].

