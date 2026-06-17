:- module(randomd, [
    detetive_preload/5,
    detetive_action/3
]).

:- use_module(library(random)).

:- dynamic known_edge/2.
:- dynamic known_city/1.
:- dynamic known_suspect/2.

detetive_preload(Grafo, Suspeitos, _Itens, _Tesouros, pronto) :-
    retractall(known_edge(_, _)),
    retractall(known_city(_)),
    retractall(known_suspect(_, _)),
    forall(member(adj(A, B), Grafo), remember_edge(A, B)),
    forall(member(procurado(Id, Aparencia), Suspeitos),
           assertz(known_suspect(Id, Aparencia))).

detetive_action(_Eventos, detective(loc(Cidade), Mandato, Pistas), Acao) :-
    findall(A, candidate_action(Cidade, Mandato, Pistas, A), Acoes),
    random_member(Acao, Acoes).

candidate_action(Cidade, _Mandato, _Pistas, move(Cidade, Destino)) :-
    neighbor(Cidade, Destino).
candidate_action(_Cidade, nenhum, Pistas, pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas).
candidate_action(_Cidade, Mandato, _Pistas, inspecionar) :-
    Mandato \= nenhum.
candidate_action(_Cidade, _Mandato, _Pistas, fechar(CidadeAlvo)) :-
    known_city(CidadeAlvo).
candidate_action(_Cidade, _Mandato, _Pistas, liberar(CidadeAlvo)) :-
    known_city(CidadeAlvo).
candidate_action(_Cidade, _Mandato, _Pistas, nada).

remember_edge(A, B) :-
    assertz(known_edge(A, B)),
    assertz(known_edge(B, A)),
    remember_city(A),
    remember_city(B).

remember_city(Cidade) :-
    known_city(Cidade),
    !.
remember_city(Cidade) :-
    assertz(known_city(Cidade)).

neighbor(A, B) :-
    known_edge(A, B).

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
subset_([X|Xs], [X|Ys]) :-
    subset_(Xs, Ys).
subset_([_|Xs], Ys) :-
    subset_(Xs, Ys).
