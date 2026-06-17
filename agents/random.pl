:- module(randomt, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- use_module(library(random)).

:- dynamic known_edge/2.
:- dynamic known_item/3.
:- dynamic known_treasure/3.
:- dynamic fake_counter/1.

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, ThiefID, ThiefObj) :-
    retractall(known_edge(_, _)),
    retractall(known_item(_, _, _)),
    retractall(known_treasure(_, _, _)),
    retractall(fake_counter(_)),
    assertz(fake_counter(0)),
    forall(member(adj(A, B), Grafo), remember_edge(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(known_item(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(known_treasure(Tesouro, Cidade, Requisitos))),
    random_member(procurado(ThiefID, _Aparencia), Suspeitos),
    random_member(tesouro(ThiefObj, _CidadeTesouro, _Reqs), Tesouros).

ladrao_action(_Eventos, thief(loc(Cidade), _Id, aparencia(Aparencia), Target, Itens, Disfarces), Acao) :-
    findall(A, candidate_action(Cidade, Aparencia, Target, Itens, Disfarces, A), Acoes),
    random_member(Acao0, Acoes),
    materialize_action(Acao0, Acao).

candidate_action(Cidade, _Aparencia, _Target, Itens, _Disfarces, roubar(Objeto)) :-
    robbable_at(Cidade, Itens, Objeto).
candidate_action(Cidade, _Aparencia, Target, Itens, _Disfarces, move(Cidade, Destino)) :-
    member(Target, Itens),
    neighbor(Cidade, Destino).
candidate_action(Cidade, _Aparencia, Target, Itens, _Disfarces, move(Cidade, Destino)) :-
    \+ member(Target, Itens),
    neighbor(Cidade, Destino).
candidate_action(_Cidade, Aparencia, _Target, _Itens, Disfarces, disfarce_fake) :-
    Disfarces > 0,
    is_list(Aparencia).
candidate_action(_Cidade, _Aparencia, _Target, _Itens, _Disfarces, nada).

robbable_at(Cidade, Itens, Objeto) :-
    known_item(Objeto, Cidade, Requisitos),
    requirements_met(Requisitos, Itens).
robbable_at(Cidade, Itens, Objeto) :-
    known_treasure(Objeto, Cidade, Requisitos),
    requirements_met(Requisitos, Itens).

requirements_met([], _Itens).
requirements_met([Req|Reqs], Itens) :-
    member(Req, Itens),
    requirements_met(Reqs, Itens).

remember_edge(A, B) :-
    assertz(known_edge(A, B)),
    assertz(known_edge(B, A)).

neighbor(A, B) :-
    known_edge(A, B).

materialize_action(disfarce_fake, disfarce([adicionar(PistaFalsa)])) :-
    next_fake_attr(PistaFalsa).
materialize_action(Acao, Acao).

next_fake_attr(pista_falsa(N)) :-
    retract(fake_counter(N0)),
    !,
    N is N0 + 1,
    assertz(fake_counter(N)).
next_fake_attr(pista_falsa(1)) :-
    assertz(fake_counter(1)).
