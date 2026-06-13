:- module(button_link, [
    button_link/3
  ]).

%!  button_link(+Href, +Label, -Html) is det.
%
%   Constrói um link estilizado em formato de botão.
button_link(Href, Label, Html) :-
    Html = a(
        [
            href(Href),
            class('inline-block rounded-xl bg-ufop-600 px-4 py-2 text-white font-semibold hover:bg-ufop-500')
        ],
        Label
    ).

