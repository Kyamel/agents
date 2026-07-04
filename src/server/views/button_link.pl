:- module(button_link, [
    button_link/3,
    auth_button_link/4
  ]).

:- use_module(ui).

button_link(Href, Label, Html) :-
    ui:primary_button_class(Class),
    Html = a(
        [
            href(Href),
            class(Class)
        ],
        Label
    ).

% Visivel so para autenticados; some (string vazia) para anonimos.
auth_button_link(anon, _Href, _Label, '') :- !.
auth_button_link(_User, Href, Label, Html) :-
    button_link(Href, Label, Html).
