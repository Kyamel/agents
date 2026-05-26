:- module(route_users, []).

:- use_module(library(http/http_dispatch)).
:- use_module('./users/[id]', []).

:- http_handler(root(users), router, [prefix]).

% Dispatcher do segmento /users. Nao ha index page; toda requisicao cai
% no arquivo dinamico users/[id].pl.
router(Request) :-
    memberchk(path(Path), Request),
    (   atom_concat('/users/', Id, Path),
        Id \== ''
    ->  route_users_show:render(Request, Id)
    ;   route_users_show:render(Request, '')
    ).
