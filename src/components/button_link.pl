:- module(button_link, [
    button_link/3,
    auth_button_link/4
  ]).

button_link(Href, Label, Html) :-
    Html = a(
        [
            href(Href),
            class('inline-block rounded-xl bg-ufop-600 px-4 py-2 text-white font-semibold hover:bg-ufop-500')
        ],
        Label
    ).

% Visivel so para autenticados; some (string vazia) para anonimos.
auth_button_link(anon, _Href, _Label, '') :- !.
auth_button_link(_User, Href, Label, Html) :-
    button_link(Href, Label, Html).

