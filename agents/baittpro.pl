:- module(baittpro, [
    ladrao_preload/7,
    ladrao_action/3
]).

% baittpro AUTOCONTIDO: contém toda a lógica do baitt (memória de grafo/itens,
% isca, disfarce inicial, escolha de tesouro/identidade, BFS) INLINE, mais as
% estratégias próprias do baittpro (disfarce forte, identidade segura e
% anti-marple). Não importa nenhum outro módulo.

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.
:- dynamic tesouro_isca/1.
:- dynamic itens_isca/1.
:- dynamic disfarce_inicial_feito/0.
:- dynamic disfarces_usados/1.
:- dynamic plano_disfarce_forte/1.
:- dynamic disfarce_forte_feito/0.

% ============================================================
% PRELOAD
% ============================================================

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, LadraoID, ObjetivoLadrao) :-
    limpar_memoria,
    limpar_memoria_local,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_conhecido(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_conhecido(Tesouro, Cidade, Requisitos))),
    forall(member(Suspeito, Suspeitos),
           assertz(suspeito_conhecido(Suspeito))),
    escolher_identidade(Suspeitos, IdOriginal),
    escolher_tesouro(ObjetivoOriginal),
    assertz(objetivo_atual(ObjetivoOriginal)),
    assertz(disfarces_usados(0)),
    escolher_isca(ObjetivoOriginal),
    % Estratégia própria do baittpro: identidade segura e anti-marple.
    escolher_identidade_segura(Suspeitos, IdOriginal, LadraoID, PlanoDisfarce),
    assertz(plano_disfarce_forte(PlanoDisfarce)),
    configurar_anti_marple(ObjetivoLadrao).

% ============================================================
% AÇÕES - ordem de prioridade
% ============================================================

% [baittpro] Disfarce forte inicial: substitui o disfarce simples do baitt por
% um conjunto de modificações que aponta para outro suspeito.
ladrao_action(_, thief(_, _, _, _, Itens, Dsg),
              disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_forte_feito,
    plano_disfarce_forte(Modificacoes),
    Modificacoes \= [],
    length(Modificacoes, Quantidade),
    Quantidade =< Dsg,
    marcar_disfarce_feito,
    !.

% [baittpro] Anti-marple: em whitechapel com obra_de_arte, rouba codigo_alarme
% para deixar ouro_do_banco pronto ao mesmo tempo (quebra a unicidade do Marple).
ladrao_action(_, thief(loc(whitechapel), _, _, obra_de_arte, Itens, _),
              roubar(codigo_alarme)) :-
    \+ memberchk(codigo_alarme, Itens),
    memberchk(radio_policial, Itens),
    !.
ladrao_action(_, thief(loc(Cidade), _, _, obra_de_arte, Itens, _),
              move(Cidade, Proxima)) :-
    \+ memberchk(codigo_alarme, Itens),
    memberchk(radio_policial, Itens),
    Cidade \= whitechapel,
    proximo_passo(Cidade, whitechapel, Proxima),
    !.

% [baitt] 1. Fuga: já tem o tesouro real
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, Vizinho)) :-
    member(Target, Itens),
    !,
    aresta_conhecida(Cidade, Vizinho).

% [baitt] 2. Disfarce inicial
ladrao_action(_, thief(loc(_), _, aparencia(AS), _Target, Itens, Dsg),
              disfarce([Modificacao])) :-
    Itens = [],
    \+ disfarce_inicial_feito,
    Dsg > 0,
    disfarces_usados(0),
    escolher_disfarce_final(AS, Modificacao),
    Modificacao \= none,
    !,
    assertz(disfarce_inicial_feito),
    retract(disfarces_usados(_)),
    assertz(disfarces_usados(1)).

% [baitt] 3. Roubar tesouro real: pré-requisitos satisfeitos
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% [baitt] 4. Rouba itens da isca antes da cadeia real ficar pronta.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(ItemIsca)) :-
    tesouro_isca(_Isca),
    itens_isca(ItensIsca),
    \+ prereqs_reais_prontos(Target, Itens),
    member(ItemIsca, ItensIsca),
    \+ member(ItemIsca, Itens),
    item_conhecido(ItemIsca, Cidade, ReqIsca),
    requisitos_satisfeitos(ReqIsca, Itens),
    \+ item_do_objetivo(ItemIsca, Target),
    !.

% [baitt] 5. Mover para pegar item da isca (se valer o desvio)
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    tesouro_isca(_Isca),
    itens_isca(ItensIsca),
    \+ prereqs_reais_prontos(Target, Itens),
    member(ItemIsca, ItensIsca),
    \+ member(ItemIsca, Itens),
    \+ item_do_objetivo(ItemIsca, Target),
    item_conhecido(ItemIsca, CidadeIsca, ReqIsca),
    requisitos_satisfeitos(ReqIsca, Itens),
    proximo_objetivo(Target, Itens, ObjetivoReal),
    cidade_do_objeto(ObjetivoReal, CidadeReal),
    distancia_bfs(Cidade, CidadeIsca, D1),
    distancia_bfs(CidadeIsca, CidadeReal, D2),
    distancia_bfs(Cidade, CidadeReal, DDireto),
    D1 + D2 - DDireto =< 2,
    !,
    proximo_passo(Cidade, CidadeIsca, ProximaCidade).

% [baitt] 6. Rouba próximo item da cadeia real
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    proximo_objetivo(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% [baitt] 7. Move para próximo objetivo
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    proximo_objetivo(Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo(Cidade, CidadeObjetivo, ProximaCidade),
    !.

ladrao_action(_, _, nada).

% ============================================================
% ESCOLHA DE ISCA
% ============================================================

escolher_isca(Target) :-
    findall(N-T,
        ( tesouro_conhecido(T, _, Reqs),
          T \= Target,
          subtract(Reqs, [T], Prereqs),
          length(Prereqs, N)
        ),
        Pares),
    Pares \= [],
    keysort(Pares, [_-Isca | _]),
    assertz(tesouro_isca(Isca)),
    tesouro_conhecido(Isca, _, ReqsIsca),
    requisitos_totais(ReqsIsca, TodosItensIsca),
    assertz(itens_isca(TodosItensIsca)),
    !.
escolher_isca(_) :-
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])).

prereqs_reais_prontos(Target, Itens) :-
    tesouro_conhecido(Target, _, Reqs),
    subtract(Reqs, [Target], Prereqs),
    forall(member(P, Prereqs), member(P, Itens)).

% ============================================================
% DISFARCE (baitt) — troca posições FINAIS da aparência
% ============================================================

escolher_disfarce_final(AS, trocar(Original, Falso)) :-
    findall(A, (member(A, AS), A \= disfarce(_,_)), Reais),
    Reais \= [],
    last(Reais, Original),
    Original =.. [Functor, ValorAtual],
    valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso),
    Falso =.. [Functor, ValorFalso],
    !.
escolher_disfarce_final(AS, omitir(Original)) :-
    findall(A, (member(A, AS), A \= disfarce(_,_)), Reais),
    Reais \= [],
    last(Reais, Original),
    !.

valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso) :-
    suspeito_conhecido(procurado(_, _Nome, aparencia(Atrs))),
    member(Attr, Atrs),
    Attr =.. [Functor, ValorFalso],
    ValorFalso \= ValorAtual,
    !.
valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso) :-
    suspeito_conhecido(procurado(_, aparencia(Atrs))),
    member(Attr, Atrs),
    Attr =.. [Functor, ValorFalso],
    ValorFalso \= ValorAtual,
    !.

% ============================================================
% DISFARCE FORTE / IDENTIDADE SEGURA / ANTI-MARPLE (baittpro)
% ============================================================

escolher_identidade_segura(Suspeitos, _IdOriginal, 9, Plano) :-
    aparencia_suspeito(9, Suspeitos,
        [A1, A2, OlhosReais, CabeloReal, UltimoReal]),
    aparencia_suspeito(1, Suspeitos,
        [A1, A2, OlhosFalsos, CabeloFalso | _]),
    Plano = [
        trocar(OlhosReais, OlhosFalsos),
        trocar(CabeloReal, CabeloFalso),
        omitir(UltimoReal)
    ],
    !.
escolher_identidade_segura(_Suspeitos, IdOriginal, IdOriginal, []).

marcar_disfarce_feito :-
    assertz(disfarce_forte_feito),
    retractall(disfarce_inicial_feito),
    assertz(disfarce_inicial_feito),
    retractall(disfarces_usados(_)),
    assertz(disfarces_usados(3)).

configurar_anti_marple(obra_de_arte) :-
    tesouro_conhecido(obra_de_arte, _, _),
    item_conhecido(codigo_alarme, _, _),
    !,
    retractall(objetivo_atual(_)),
    assertz(objetivo_atual(obra_de_arte)),
    retractall(tesouro_isca(_)),
    assertz(tesouro_isca(ouro_do_banco)),
    retractall(itens_isca(_)),
    assertz(itens_isca([codigo_alarme])).
configurar_anti_marple(Objetivo) :-
    objetivo_atual(Objetivo).

limpar_memoria_local :-
    retractall(plano_disfarce_forte(_)),
    retractall(disfarce_forte_feito).

% ============================================================
% MEMÓRIA
% ============================================================

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)),
    retractall(tesouro_isca(_)),
    retractall(itens_isca(_)),
    retractall(disfarce_inicial_feito),
    retractall(disfarces_usados(_)).

lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).

% ============================================================
% ESCOLHA DE TESOURO
% ============================================================

escolher_tesouro(Tesouro) :-
    findall(Quantidade-T, quantidade_requisitos_tesouro(T, Quantidade), Pares),
    keysort(Pares, [_-Tesouro | _]).

quantidade_requisitos_tesouro(Tesouro, Quantidade) :-
    tesouro_conhecido(Tesouro, _, Requisitos),
    requisitos_totais(Requisitos, Todos),
    length(Todos, Quantidade).

requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Req, requisito_recursivo(Requisitos, Req), Todos),
    sort(Todos, TodosUnicos).

requisito_recursivo(Requisitos, Req) :-
    member(Req, Requisitos).
requisito_recursivo(Requisitos, ReqIndireto) :-
    member(Req, Requisitos),
    item_conhecido(Req, _, SubRequisitos),
    requisito_recursivo(SubRequisitos, ReqIndireto).

% ============================================================
% ESCOLHA DE IDENTIDADE
% ============================================================

escolher_identidade(Suspeitos, LadraoID) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_-LadraoID | _]).

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _Nome, aparencia(Aparencia)), Suspeitos), !.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, aparencia(Aparencia)), Suspeitos).

pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao) :-
    findall(Quantidade,
        ( prefixo(Aparencia, Prefixo),
          Prefixo \= [],
          contar_compativeis(Prefixo, Suspeitos, Quantidade)
        ),
        Quantidades),
    sum_list(Quantidades, Pontuacao).

contar_compativeis(Prefixo, Suspeitos, Quantidade) :-
    findall(Id,
        ( aparencia_suspeito(Id, Suspeitos, OutraAparencia),
          prefixo_compativel(Prefixo, OutraAparencia)
        ),
        Ids),
    length(Ids, Quantidade).

prefixo(Lista, Prefixo) :-
    append(Prefixo, _Resto, Lista).

prefixo_compativel([], _).
prefixo_compativel([A | As], [A | Bs]) :-
    prefixo_compativel(As, Bs).

% ============================================================
% REQUISITOS E PRÓXIMO OBJETIVO
% ============================================================

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    member(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

proximo_objetivo(Target, Itens, ProximoObjeto) :-
    tesouro_conhecido(Target, _, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito(Req, Itens, ProximoObjeto).
proximo_objetivo(Target, _, Target).

resolver_requisito(Item, Itens, ProximoObjeto) :-
    item_conhecido(Item, _, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito(Req, Itens, ProximoObjeto).
resolver_requisito(Item, _, Item).

requisito_pendente([Req | _], Itens, Req) :-
    \+ member(Req, Itens), !.
requisito_pendente([_ | Resto], Itens, Pendente) :-
    requisito_pendente(Resto, Itens, Pendente).

cidade_do_objeto(Objeto, Cidade) :-
    item_conhecido(Objeto, Cidade, _), !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_conhecido(Objeto, Cidade, _).

item_do_objetivo(Item, Target) :-
    tesouro_conhecido(Target, _, Requisitos),
    requisito_recursivo(Requisitos, Item).

% ============================================================
% BFS
% ============================================================

proximo_passo(Origem, Destino, ProximaCidade) :-
    caminho_mais_curto(Origem, Destino, [Origem, ProximaCidade | _]).

caminho_mais_curto(Origem, Destino, Caminho) :-
    bfs([[Origem]], [Origem], Destino, CaminhoInvertido),
    reverse(CaminhoInvertido, Caminho).

bfs([[Destino | Resto] | _], _, Destino, [Destino | Resto]) :- !.
bfs([CaminhoAtual | OutrosCaminhos], Visitados, Destino, Caminho) :-
    estender_caminho(CaminhoAtual, Visitados, NovosCaminhos, NovosVizinhos),
    append(Visitados, NovosVizinhos, VisitadosAtualizado),
    append(OutrosCaminhos, NovosCaminhos, FilaAtualizada),
    bfs(FilaAtualizada, VisitadosAtualizado, Destino, Caminho).

estender_caminho([Atual | Visitados], JaVistos, NovosCaminhos, NovosVizinhos) :-
    findall(Vizinho,
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        NovosVizinhos),
    findall([Vizinho, Atual | Visitados],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos).

distancia_bfs(Origem, Destino, 0) :- Origem = Destino, !.
distancia_bfs(Origem, Destino, Dist) :-
    bfs_dist([[Origem, 0]], [Origem], Destino, Dist).

bfs_dist([[Dest, D] | _], _, Dest, D) :- !.
bfs_dist([[Atual, D] | Fila], Visitados, Dest, Dist) :-
    D1 is D + 1,
    findall([Viz, D1],
        ( aresta_conhecida(Atual, Viz),
          \+ memberchk(Viz, Visitados)
        ),
        Novos),
    findall(Viz, member([Viz, _], Novos), NovosViz),
    append(Visitados, NovosViz, VisitadosAtualizado),
    append(Fila, Novos, FilaAtualizada),
    bfs_dist(FilaAtualizada, VisitadosAtualizado, Dest, Dist).
