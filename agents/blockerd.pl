:- module(blockerd, [
    detetive_preload/5,
    detetive_action/3
]).

:- dynamic known_city/1.
:- dynamic known_lock/1.
:- dynamic known_suspect/2.

%!  detetive_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto) is det.
%
%   Detetive especializado em bloqueio. Ele fecha a cidade do roubo mais
%   recente, que e a resposta mais agressiva contra fuga imediata.
detetive_preload(Grafo, Suspeitos, _Itens, _Tesouros, pronto) :-
    retractall(known_city(_)),
    retractall(known_lock(_)),
    retractall(known_suspect(_, _)),
    forall(member(adj(A, B), Grafo),
           (remember_city(A), remember_city(B))),
    forall(member(procurado(Id, Aparencia), Suspeitos),
           assertz(known_suspect(Id, Aparencia))).

detetive_action(Eventos, _Estado, fechar(Cidade)) :-
    latest_robbery_city(Eventos, Cidade),
    remember_lock(Cidade),
    !.
detetive_action(_Eventos, _Estado, fechar(Cidade)) :-
    unlocked_city(Cidade),
    remember_lock(Cidade),
    !.
detetive_action(_Eventos, detective(_, nenhum, Pistas), pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas),
    !.
detetive_action(_, detective(_, Mandato, _), inspecionar) :-
    Mandato \= nenhum,
    !.
detetive_action(_, _, nada).

remember_city(Cidade) :-
    known_city(Cidade),
    !.
remember_city(Cidade) :-
    assertz(known_city(Cidade)).

remember_lock(Cidade) :-
    known_lock(Cidade),
    !.
remember_lock(Cidade) :-
    assertz(known_lock(Cidade)).

unlocked_city(Cidade) :-
    known_city(Cidade),
    \+ known_lock(Cidade).

latest_robbery_city([roubo(_, Cidade, _) | _], Cidade) :- !.
latest_robbery_city([_ | Eventos], Cidade) :-
    latest_robbery_city(Eventos, Cidade).

possible_warrant(Pistas, Id, SubPistas) :-
    non_empty_subset(Pistas, SubPistas),
    compatible_suspects(SubPistas, Suspeitos),
    length(Suspeitos, K),
    K =< 2,
    member(Id, Suspeitos).

compatible_suspects(Pistas, Suspeitos) :-
    findall(Id, suspect_matches(Pistas, Id), Suspeitos).

suspect_matches(Pistas, Id) :-
    known_suspect(Id, aparencia(Atributos)),
    forall(member(Pista, Pistas), member(Pista, Atributos)).

non_empty_subset(Lista, Subset) :-
    subset_(Lista, Subset),
    Subset \= [].

subset_([], []).
subset_([X | Xs], [X | Ys]) :-
    subset_(Xs, Ys).
subset_([_ | Xs], Ys) :-
    subset_(Xs, Ys).
