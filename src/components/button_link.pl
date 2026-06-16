:- module(button_link, [
    button_link/3,
    auth_button_link/4
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

%!  auth_button_link(+User, +Href, +Label, -Html) is det.
%
%   Botão-link visível apenas para usuários autenticados; some (string vazia)
%   para visitantes anônimos. Usado nos CTAs das telas de listagem.
auth_button_link(anon, _Href, _Label, '') :- !.
auth_button_link(_User, Href, Label, Html) :-
    button_link(Href, Label, Html).

