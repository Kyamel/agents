:- module(chaserd, [
    detetive_preload/5,
    detetive_action/3
]).

:- use_module(library(lists)).

:- dynamic known_edge/2.
:- dynamic known_city/1.
:- dynamic known_suspect/2.

%!  detetive_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto) is det.
%
%   Detetive perseguidor: usa a cidade do roubo mais recente como alvo de
%   movimento. Nao fecha cidades, para isolar pressao espacial por perseguicao.
detetive_preload(Grafo, Suspeitos, _Itens, _Tesouros, pronto) :-
    retractall(known_edge(_, _)),
    retractall(known_city(_)),
    retractall(known_suspect(_, _)),
    forall(member(adj(A, B), Grafo), remember_edge(A, B)),
    forall(member(procurado(Id, Aparencia), Suspeitos),
           assertz(known_suspect(Id, Aparencia))).

detetive_action(_, detective(_, nenhum, Pistas), pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas),
    !.
detetive_action(_, detective(_, Mandato, _), inspecionar) :-
    Mandato \= nenhum,
    !.
detetive_action(Eventos, detective(loc(Cidade), _, _), move(Cidade, Proxima)) :-
    latest_robbery_city(Eventos, Alvo),
    Cidade \= Alvo,
    proximo_passo(Cidade, Alvo, Proxima),
    !.
detetive_action(_, detective(loc(Cidade), _, _), move(Cidade, Proxima)) :-
    melhor_patrulha(Cidade, Proxima),
    !.
detetive_action(_, _, nada).

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

latest_robbery_city([roubo(_, Cidade, _) | _], Cidade) :- !.
latest_robbery_city([_ | Eventos], Cidade) :-
    latest_robbery_city(Eventos, Cidade).

melhor_patrulha(Cidade, Proxima) :-
    setof(Score-Vizinho,
        ( known_edge(Cidade, Vizinho),
          grau(Vizinho, Grau),
          Score is -Grau
        ),
        [_-Proxima | _]).

proximo_passo(Origem, Destino, Proxima) :-
    caminho_mais_curto(Origem, Destino, [Origem, Proxima | _]).

caminho_mais_curto(Origem, Destino, Caminho) :-
    setof(L-P,
        ( caminho_simples(Origem, Destino, [Origem], P),
          length(P, L)
        ),
        [_-Caminho | _]).

caminho_simples(Destino, Destino, Visitados, Caminho) :-
    reverse(Visitados, Caminho).
caminho_simples(Atual, Destino, Visitados, Caminho) :-
    known_edge(Atual, Vizinho),
    \+ member(Vizinho, Visitados),
    caminho_simples(Vizinho, Destino, [Vizinho | Visitados], Caminho).

grau(Cidade, Grau) :-
    findall(V, known_edge(Cidade, V), Vs),
    sort(Vs, Unicos),
    length(Unicos, Grau).

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
