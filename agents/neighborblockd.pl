:- module(neighborblockd, [
    detetive_preload/5,
    detetive_action/3
]).

:- dynamic known_edge/2.
:- dynamic known_city/1.
:- dynamic known_suspect/2.
:- dynamic known_lock/1.
:- dynamic queued_block/1.
:- dynamic last_seen_robbery/2.

%!  detetive_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto) is det.
%
%   Detetive anti-delay: quando ve um roubo, assume que o ladrao ja saiu da
%   cidade roubada e passa a fechar as cidades vizinhas a ela.
detetive_preload(Grafo, Suspeitos, _Itens, _Tesouros, pronto) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(procurado(Id, Aparencia), Suspeitos),
           assertz(known_suspect(Id, Aparencia))).

%!  detetive_action(+Eventos, +EstadoDetetive, -Acao) is det.
%
%   Atualiza a fila de bloqueios a partir do roubo mais recente, fecha um
%   vizinho por turno e usa mandato como pressao secundaria.
detetive_action(Eventos, detective(_, Mandato, Pistas), Acao) :-
    atualizar_fila(Eventos),
    escolher_acao(Mandato, Pistas, Acao),
    !.
detetive_action(_, _, nada).


% --- Politica

escolher_acao(_Mandato, _Pistas, fechar(Cidade)) :-
    proximo_bloqueio(Cidade),
    lembrar_lock(Cidade),
    !.
escolher_acao(nenhum, Pistas, pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas),
    !.
escolher_acao(Mandato, _Pistas, inspecionar) :-
    Mandato \= nenhum,
    !.
escolher_acao(_, _, nada).

proximo_bloqueio(Cidade) :-
    retract(queued_block(Cidade)),
    \+ known_lock(Cidade),
    !.
proximo_bloqueio(Cidade) :-
    retract(queued_block(_)),
    proximo_bloqueio(Cidade).


% --- Fila de vizinhos do roubo

atualizar_fila(Eventos) :-
    ultimo_roubo(Eventos, Item, Cidade),
    \+ last_seen_robbery(Item, Cidade),
    !,
    retractall(queued_block(_)),
    assertz(last_seen_robbery(Item, Cidade)),
    enfileirar_vizinhos(Cidade).
atualizar_fila(_).

ultimo_roubo([roubo(Item, Cidade, _) | _], Item, Cidade) :- !.
ultimo_roubo([_ | Eventos], Item, Cidade) :-
    ultimo_roubo(Eventos, Item, Cidade).

enfileirar_vizinhos(Cidade) :-
    findall(Score-Vizinho,
        ( known_edge(Cidade, Vizinho),
          \+ known_lock(Vizinho),
          grau(Vizinho, Grau),
          Score is -Grau
        ),
        Pares),
    keysort(Pares, Ordenados),
    forall(member(_-Vizinho, Ordenados),
           assertz(queued_block(Vizinho))).


% --- Mapa e memoria

limpar_memoria :-
    retractall(known_edge(_, _)),
    retractall(known_city(_)),
    retractall(known_suspect(_, _)),
    retractall(known_lock(_)),
    retractall(queued_block(_)),
    retractall(last_seen_robbery(_, _)).

lembrar_aresta(A, B) :-
    assertz(known_edge(A, B)),
    assertz(known_edge(B, A)),
    lembrar_cidade(A),
    lembrar_cidade(B).

lembrar_cidade(Cidade) :-
    known_city(Cidade),
    !.
lembrar_cidade(Cidade) :-
    assertz(known_city(Cidade)).

lembrar_lock(Cidade) :-
    known_lock(Cidade),
    !.
lembrar_lock(Cidade) :-
    assertz(known_lock(Cidade)).

grau(Cidade, Grau) :-
    findall(V, known_edge(Cidade, V), Vs),
    sort(Vs, Unicos),
    length(Unicos, Grau).


% --- Mandato

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
