% ============================================================
% DETETIVE: balanced_d
%
% Detetive misto. Combina tres pressoes: pede mandato cedo (assim que as
% pistas reduzem os suspeitos a <=2), fecha a cidade do roubo recente, e,
% quando nao ha evento novo util, patrulha em direcao as cidades de
% tesouro. Sem se especializar, aplica pressao de bloqueio + mandato +
% posicionamento ao mesmo tempo.
% Generalista: raramente e o pior contra qualquer ladrao, mas tambem
% nao explora nenhuma fraqueza especifica a fundo.
% ============================================================

:- module(balanced_d, [
    detetive_preload/5,
    detetive_action/3
]).

:- dynamic known_edge/2.
:- dynamic known_city/1.
:- dynamic known_suspect/2.
:- dynamic known_lock/1.
:- dynamic treasure_city/1.

%!  detetive_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto) is det.
%
%   Detetive misto: pede mandato cedo, fecha cidade de roubo recente e, quando
%   nao ha evento novo util, patrulha em direcao a tesouros.
detetive_preload(Grafo, Suspeitos, _Itens, Tesouros, pronto) :-
    retractall(known_edge(_, _)),
    retractall(known_city(_)),
    retractall(known_suspect(_, _)),
    retractall(known_lock(_)),
    retractall(treasure_city(_)),
    forall(member(adj(A, B), Grafo), remember_edge(A, B)),
    forall(member(procurado(Id, Aparencia), Suspeitos),
           assertz(known_suspect(Id, Aparencia))),
    forall(member(tesouro(_, Cidade, _), Tesouros),
           remember_treasure_city(Cidade)).

detetive_action(_, detective(_, nenhum, Pistas), pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas),
    !.
detetive_action(Eventos, _Estado, fechar(Cidade)) :-
    latest_robbery_city(Eventos, Cidade),
    \+ known_lock(Cidade),
    assertz(known_lock(Cidade)),
    !.
detetive_action(Eventos, detective(loc(Cidade), Mandato, _), move(Cidade, Proxima)) :-
    Mandato \= nenhum,
    latest_robbery_city(Eventos, Alvo),
    Cidade \= Alvo,
    proximo_passo(Cidade, Alvo, Proxima),
    !.
detetive_action(_, detective(_, Mandato, _), inspecionar) :-
    Mandato \= nenhum,
    !.
detetive_action(_, _Estado, fechar(Cidade)) :-
    treasure_city(Cidade),
    \+ known_lock(Cidade),
    assertz(known_lock(Cidade)),
    !.
detetive_action(Eventos, detective(loc(Cidade), _, _), move(Cidade, Proxima)) :-
    latest_robbery_city(Eventos, Alvo),
    Cidade \= Alvo,
    proximo_passo(Cidade, Alvo, Proxima),
    !.
detetive_action(_, detective(loc(Cidade), _, _), move(Cidade, Proxima)) :-
    nearest_treasure_city(Cidade, Alvo),
    Cidade \= Alvo,
    proximo_passo(Cidade, Alvo, Proxima),
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

remember_treasure_city(Cidade) :-
    treasure_city(Cidade),
    !.
remember_treasure_city(Cidade) :-
    assertz(treasure_city(Cidade)).

latest_robbery_city([roubo(_, Cidade, _) | _], Cidade) :- !.
latest_robbery_city([_ | Eventos], Cidade) :-
    latest_robbery_city(Eventos, Cidade).

nearest_treasure_city(Cidade, Alvo) :-
    setof(L-T,
        ( treasure_city(T),
          caminho_mais_curto(Cidade, T, Caminho),
          length(Caminho, L)
        ),
        [_-Alvo | _]).

proximo_passo(Origem, Destino, Proxima) :-
    caminho_mais_curto(Origem, Destino, [Origem, Proxima | _]).

caminho_mais_curto(Origem, Destino, Caminho) :-
    bfs([[Origem]], [Origem], Destino, CaminhoInvertido),
    reverse(CaminhoInvertido, Caminho).

bfs([[Destino | Resto] | _], _Visitados, Destino, [Destino | Resto]) :-
    !.
bfs([CaminhoAtual | OutrosCaminhos], Visitados, Destino, Caminho) :-
    estender_caminho(CaminhoAtual, Visitados, NovosCaminhos, NovosVizinhos),
    append(Visitados, NovosVizinhos, VisitadosAtualizado),
    append(OutrosCaminhos, NovosCaminhos, FilaAtualizada),
    bfs(FilaAtualizada, VisitadosAtualizado, Destino, Caminho).

estender_caminho([Atual | Visitados], JaVistos, NovosCaminhos, NovosVizinhos) :-
    findall(Vizinho,
        ( known_edge(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        NovosVizinhos),
    findall([Vizinho, Atual | Visitados],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos).

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
