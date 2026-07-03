% ============================================================
%  Detetive Marple — Agente Inteligente (v3.0)
%
%  Disciplina CSI107 - Linguagens de Programacao (DECSI/UFOP).
%  Estrategia: fechar reativo (nao-perder) + caca por mandato
%  posicional (maximizar capturas). Ver docs/DETETIVE_MARPLE.md.
%
%  --- Camada 1: nucleo "nao perde" -------------------------------
%  P1 fechar PREDITIVO: fecha a cidade-alvo assim que TODOS os
%  pre-requisitos do tesouro (exceto ele mesmo) aparecem em Events —
%  ou seja, no MAIS TARDIO entre "ultimo item da cadeia roubado" e
%  "tesouro roubado", o que for visivel primeiro. Existe desde a
%  v3.0 porque o motor corrigido pelo professor (2026-06) passou a
%  ter DELAY de 1 rodada entre um roubo acontecer e o evento ficar
%  visivel pro detetive (getEvents so reflete eventos "liberados";
%  um roubo fica "pendente" durante o turno do detetive imediatamente
%  seguinte). Esperar o evento do PROPRIO tesouro (v2.1) deixou de
%  ser seguro: o turno do detetive que segue o roubo do tesouro nao
%  vê mais esse roubo (delay), entao um ladrao que foge imediatamente
%  escapa sempre. Fechar no penultimo evento da cadeia (1 furto antes)
%  absorve exatamente essa rodada perdida — ver prova e limites em
%  docs/TESTES_ADVERSARIOS.md.
%
%  --- Camada 2: caca ao ladrao que SENTA (maximizar vitorias) ----
%  Um ladrao pode roubar o tesouro e NAO fugir (fica parado na
%  cidade fechada). Contra um detetive so-fechar isso e empate — e
%  empate vale ZERO na competicao (so vitorias absolutas contam, ver
%  docs/REGRAS_NAO_ESCRITAS.md). v2.0 converte esses empates em
%  vitoria via mandato + inspecionar, com duas ideias-chave:
%
%    1. MANDATO TARDIO: so pede mandato apos o tesouro ser roubado
%       ("heist-done") = informacao maxima. O mandato e ONE-SHOT e
%       PERMANENTE (o Interactor so aceita pedir_mandato com mandato
%       'nenhum'); pedir cedo, sobre pistas ainda corrompidas por
%       disfarce, trava no ID errado para sempre. Esperar nao custa
%       nada — o ladrao que senta nao vai a lugar nenhum.
%
%    2. MANDATO POSICIONAL: o disfarce afeta os PRIMEIROS atributos
%       (primeiros revelados); logo as pistas reveladas mais TARDE
%       sao as mais reais. O mandato le a ordem das revelacoes nos
%       Events e confia no sufixo (posicoes altas). Robusto a
%       QUALQUER ID de ladrao — a versao anterior (v1.x) so capturava
%       disfarcados por acaso, quando o ladrao era ID 0.
% ============================================================

:- module('marpled', [detetive_action/3, detetive_preload/5]).

:- dynamic mp_adj/2.
:- dynamic mp_suspect/2.
:- dynamic mp_item/3.
:- dynamic mp_treasure/3.
:- dynamic mp_treasure_deps/2.
:- dynamic mp_closed/1.

% ============================================================
% PRELOAD
% ============================================================

detetive_preload(G, LS, LI, LT, pronto) :-
    retractall(mp_adj(_,_)),
    retractall(mp_suspect(_,_)),
    retractall(mp_item(_,_,_)),
    retractall(mp_treasure(_,_,_)),
    retractall(mp_treasure_deps(_,_)),
    retractall(mp_closed(_)),
    forall(member(adj(A,B), G), (assertz(mp_adj(A,B)), assertz(mp_adj(B,A)))),
    forall(member(procurado(ID,AP), LS), assertz(mp_suspect(ID,AP))),
    forall(member(item(N,C,XS), LI), assertz(mp_item(N,C,XS))),
    forall(member(tesouro(N,C,XS), LT), assertz(mp_treasure(N,C,XS))),
    forall(mp_treasure(TName,_,_), (
        mp_all_deps(TName, Deps),
        assertz(mp_treasure_deps(TName, Deps))
    )).

% ============================================================
% ACAO PRINCIPAL
% ============================================================

detetive_action(Events, detective(loc(C), M, Clues), Action) :-
    mp_decide(Events, C, M, Clues, Action).

% --- P1: FECHAR PREDITIVO POR-TESOURO (nucleo "nao perde") ----------
% Fecha a cidade do tesouro T assim que TODOS os seus pre-requisitos
% (Deps(T) menos o proprio T) ja apareceram em Events. Como o roubo do
% proprio T exige ter coletado antes cada um desses pre-requisitos
% (cada um e seu proprio roubar/1, validado pelo motor), este teste
% fica verdadeiro no MESMO turno em que T e roubado OU ANTES (no
% roubo do ultimo pre-requisito da cadeia) — nunca depois.
%
% Por que "ANTES" importa agora (mudanca v2.1 -> v3.0):
%   O motor corrigido pelo professor adiou a visibilidade de QUALQUER
%   evento por exatamente 1 rodada (ver cabecalho do arquivo). Esperar
%   o evento do PROPRIO tesouro (v2.1) significa descobrir o roubo so
%   na 2a chamada de detetive_action depois dele — uma rodada tarde
%   demais, pois o ladrao ja teve a chance de fugir no meio. Fechar
%   reagindo ao penultimo evento da cadeia (quando ela tem >=1
%   pre-requisito, o caso de todo cenario usado aqui) dispara 1 furto
%   mais cedo, e esse furto sempre acontece em um turno do ladrao
%   ANTERIOR ao turno em que ele rouba T — ou seja, o fechamento chega
%   a tempo mesmo com a rodada de atraso. Prova passo-a-passo em
%   docs/TESTES_ADVERSARIOS.md.
%
% Por que isso continua imune ao "ladrao_iscador" (mudanca v2.0->v2.1,
% preservada aqui): mp_ready_target/2 olha, PARA CADA tesouro
% separadamente, se a INTERSECCAO de Events com a cadeia DAQUELE
% tesouro esta completa — um item-isca de OUTRA cadeia simplesmente
% nao aparece nessa intersecao, entao nao contamina o teste (ao
% contrario da v2.0, que exigia o conjunto INTEIRO de itens roubados
% consistente com um unico tesouro, e quebrava com 1 item fora do
% padrao).
%
% Limite conhecido (cenario novo teria que ser desenhado assim de
% proposito): um tesouro com ZERO pre-requisitos nao tem "penultimo
% evento" para reagir — nesse caso especifico nao ha sinal algum antes
% do proprio roubo, e a rodada de atraso fica inevitavel. Nenhum dos
% cenarios em src/cenarios/ tem tesouro sem pre-requisito (verificado).
%
% So fecha uma vez por tesouro (\+ mp_closed): a partir do momento em
% que T fica "pronto", a inferencia permanece valida o resto da
% partida (a cadeia ja coletada nao se desfaz), entao mp_closed/1
% nunca acumula mais de um fato (respeita "uma cidade fechada por
% vez" — alem disso, o motor agora IMPOE isso tambem: fechar/1
% substitui a lista Locks por [C], nao acumula mais).
mp_decide(Events, _, _, _, fechar(TCity)) :-
    mp_stolen_items(Events, Stolen),
    Stolen \= [],
    mp_ready_target(Stolen, TName),
    mp_treasure(TName, TCity, _),
    \+ mp_closed(TCity),
    assertz(mp_closed(TCity)), !.

% --- P2: capturar o ladrao que SENTOU ------------------------------
% Heist ja aconteceu, ja tenho mandato e estou na cidade do ultimo
% roubo (= cidade do tesouro, onde o ladrao que senta esta preso).
mp_decide(Events, C, mandato(_), _, inspecionar) :-
    mp_heist_done(Events),
    mp_last_theft_city(Events, C), !.

% --- P3: ir ate o ladrao que sentou para inspecionar ---------------
mp_decide(Events, C, mandato(_), _, move(C, Next)) :-
    mp_heist_done(Events),
    mp_last_theft_city(Events, TCity),
    TCity \= C,
    mp_next_step(C, TCity, Next),
    Next \= C, !.

% --- P4: pedir mandato TARDIO e POSICIONAL -------------------------
% So depois do heist (informacao maxima), e so se conseguir um
% mandato valido confiando nas pistas reveladas MAIS TARDE.
mp_decide(Events, _, nenhum, _Clues, pedir_mandato(ID, Sub)) :-
    mp_heist_done(Events),
    mp_warrant(Events, ID, Sub), !.

% --- P5: pre-heist, fica perto do ladrao (cidade do ultimo roubo) ---
mp_decide(Events, C, _, _, move(C, Next)) :-
    mp_last_theft_city(Events, TCity),
    TCity \= C,
    mp_next_step(C, TCity, Next),
    Next \= C, !.

% --- P6: nenhum roubo ainda -> posiciona-se estrategicamente --------
mp_decide(_, C, _, _, move(C, Next)) :-
    mp_best_treasure_city(TCity),
    mp_next_step(C, TCity, Next),
    Next \= C, !.

mp_decide(_, _, _, _, nada).

% ============================================================
% EVENTOS DE ROUBO
% ============================================================

% cidade do roubo mais recente (eventos vem com o mais novo na cabeca)
mp_last_theft_city([roubo(_,C,_)|_], C) :- !.

% heist-done: algum tesouro ja foi roubado (a partir dai nao chegam
% mais pistas novas -> momento certo de comprometer o mandato one-shot)
mp_heist_done(Events) :-
    member(roubo(I,_,_), Events),
    mp_treasure(I, _, _), !.

% todos os nomes de item/tesouro ja roubados, na visao do detetive
% (ou seja, sujeitos ao delay de visibilidade do motor — ver P1)
mp_stolen_items(Events, Stolen) :-
    findall(I, member(roubo(I,_,_), Events), Stolen).

% tesouro "pronto": TODOS os seus pre-requisitos (Deps menos ele
% mesmo) ja estao entre os itens roubados visiveis. Olha cada tesouro
% isoladamente (intersecao com a SUA propria cadeia), entao um item de
% cadeia alheia (isca) nunca derruba um candidato real — e exige
% candidato UNICO (mesma garantia de certeza que a v2.1 tinha ao
% ler o evento do proprio tesouro).
mp_ready_target(Stolen, TName) :-
    findall(T,
        ( mp_treasure_deps(T, Deps),
          subtract(Deps, [T], Prereqs),
          forall(member(P, Prereqs), member(P, Stolen))
        ),
        [TName]).

% ============================================================
% MANDATO POSICIONAL ROBUSTO A DISFARCE
% ============================================================
%
% O disfarce afeta os PRIMEIROS atributos da aparencia (que sao os
% primeiros revelados a cada roubo — ver Interactor: takeAttr pega o
% prefixo da lista de aparencia). Logo, as pistas reveladas MAIS
% TARDE (posicoes mais altas) sao as mais provavelmente REAIS.
%
% A lista de Events preserva, em cada roubo, a sublista ORDENADA de
% atributos revelados (posicoes 1..N) — ao contrario de Clues, que e
% o conjunto achatado (perde a ordem). Por isso o mandato le os
% Events: pega a revelacao mais rica (a mais longa) e confia no seu
% SUFIXO (posicoes altas), atacando exatamente o ponto fraco do
% disfarce. Isso captura o ladrao disfarcado sempre que pelo menos
% uma caracteristica real for revelada e for distintiva — e e robusto
% a QUALQUER ID de ladrao (o marple so acertava por sorte quando o
% ladrao era ID 0).

mp_warrant(Events, ID, Sub) :-
    mp_richest_reveal(Events, R),          % atributos em ordem de posicao 1..m
    mp_valid_only(R, RV),                  % descarta 'none' / pistas que ninguem tem
    RV \= [],
    reverse(RV, Trusted),                  % posicoes altas (reais) primeiro
    (   mp_prefix_warrant(Trusted, ID, Sub) % preferido: confia nas pistas tardias
    ;   mp_subset_warrant(RV, ID, Sub)      % fallback (piso estilo marple)
    ), !.

% revelacao mais rica = a sublista de pistas mais longa entre os eventos
mp_richest_reveal(Events, R) :-
    findall(L-P, (member(roubo(_,_,P), Events), length(P, L)), Ps),
    Ps \= [],
    sort(0, @>=, Ps, [_-R|_]).

% mantem so pistas que algum suspeito realmente possui (descarta
% 'none' de omissao e quaisquer marcadores nao mapeaveis)
mp_valid_only([], []).
mp_valid_only([C|Cs], [C|RV]) :- mp_some_suspect_has(C), !, mp_valid_only(Cs, RV).
mp_valid_only([_|Cs], RV) :- mp_valid_only(Cs, RV).

mp_some_suspect_has(C) :- mp_suspect(_, aparencia(A)), memberchk(C, A), !.

% menor PREFIXO das pistas confiaveis (posicoes altas primeiro) que
% reduz os suspeitos a <=2; nomeia o de menor ID entre os
% sobreviventes (todos consistentes com as pistas reais)
mp_prefix_warrant(Trusted, ID, Sub) :-
    length(Trusted, Max),
    between(1, Max, N),
    length(Sub, N),
    append(Sub, _, Trusted),
    mp_match_suspects(Sub, IDs),
    length(IDs, K), K >= 1, K =< 2, !,
    min_list(IDs, ID).

% fallback estilo marple: menor subconjunto QUALQUER das pistas
% validas que reduz a <=2 (usado so se nenhum prefixo confiavel
% formar mandato valido)
mp_subset_warrant(RV, ID, Sub) :-
    length(RV, Max),
    between(1, Max, N),
    length(Sub, N),
    mp_sublist(Sub, RV),
    ground(Sub),
    mp_match_suspects(Sub, IDs),
    length(IDs, K), K >= 1, K =< 2, !,
    min_list(IDs, ID).

mp_match_suspects(Attrs, IDs) :-
    findall(ID,
        (mp_suspect(ID, aparencia(SAttrs)),
         mp_all_in(Attrs, SAttrs)),
        IDs).

mp_all_in([], _).
mp_all_in([H|T], List) :- member(H, List), !, mp_all_in(T, List).

mp_sublist([], _).
mp_sublist([H|T], List) :- select(H, List, Rest), mp_sublist(T, Rest).

% ============================================================
% POSICIONAMENTO
% ============================================================

mp_best_treasure_city(TCity) :-
    findall(K-TCity1,
        (mp_treasure_deps(TName, Deps), length(Deps, K),
         mp_treasure(TName, TCity1, _)),
        Pairs),
    Pairs \= [],
    msort(Pairs, Sorted),
    last(Sorted, _-TCity), !.
mp_best_treasure_city(TCity) :-
    mp_treasure(_, TCity, _), !.

% ============================================================
% BFS — caminho mais curto (com guarda de "sem caminho")
% ============================================================

mp_next_step(X, X, X) :- !.
mp_next_step(From, To, Next) :-
    mp_bfs([[From]], To, RevPath),
    reverse(RevPath, [From, Next | _]), !.
mp_next_step(From, _, From).

mp_bfs([[Goal|Rest]|_], Goal, [Goal|Rest]) :- !.
mp_bfs([[Current|Visited]|Queue], Goal, Path) :-
    findall(
        [Nbr,Current|Visited],
        (mp_adj(Current, Nbr), \+ member(Nbr, [Current|Visited])),
        Ext),
    append(Queue, Ext, NQ),
    NQ \= [],
    mp_bfs(NQ, Goal, Path).

% ============================================================
% DEPENDENCIAS TRANSITIVAS
% ============================================================

mp_all_deps(Name, Deps) :-
    mp_deps_acc([Name], [], Deps).

mp_deps_acc([], Acc, Acc) :- !.
mp_deps_acc([H|T], Vis, Res) :-
    (member(H, Vis) ->
        mp_deps_acc(T, Vis, Res)
    ;
        (   mp_item(H,_,Reqs)    -> true
        ;   mp_treasure(H,_,Reqs) -> true
        ;   Reqs = []
        ),
        append(T, Reqs, NQ),
        mp_deps_acc(NQ, [H|Vis], Res)
    ).