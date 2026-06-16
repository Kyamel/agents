:- module(route_matches_map, []).

:- use_module(library(http/http_dispatch)).
:- use_module('./matches_show').

:- http_handler('/map/', handler, [method(get), prefix]).

handler(Request) :-
    memberchk(path(Path), Request),
    extract_id(Path, Id),
    !,
    route_matches_show:render_map(Request, Id).
handler(Request) :-
    http_redirect(see_other, '/matches', Request).

extract_id(Path, Id) :-
    atom_concat('/map/', Id, Path),
    Id \== ''.
