% ============================================================
% LADRAO: greedy_t
%
% Ladrao guloso de referencia. A cada turno: se ja tem o tesouro-alvo,
% foge para um vizinho qualquer; se esta na cidade de algo roubavel,
% rouba; senao caminha pelo menor caminho ate o proximo objetivo util.
% Sem disfarce elaborado, sem isca e sem evasao — coleta a cadeia real
% pelo caminho mais curto e sai. Simples e previsivel: bom baseline,
% vulneravel a detetives que preveem o menor caminho e a mandato.
% ============================================================

:- module(greedy_t, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, LadraoID, ObjetivoLadrao) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo),
           lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_conhecido(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_conhecido(Tesouro, Cidade, Requisitos))),
    forall(member(Suspeito, Suspeitos),
           assertz(suspeito_conhecido(Suspeito))),
    escolher_identidade(Suspeitos, LadraoID),
    escolher_tesouro(ObjetivoLadrao),
    assertz(objetivo_atual(ObjetivoLadrao)).

ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, Vizinho)) :-
    % Se já tem o tesouro, fugir.
    member(Target, Itens),
    !,
    aresta_conhecida(Cidade, Vizinho).
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Target)) :-
    % Se o tesouro está aqui e pode roubar, roubar.
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    % Se o próximo item está aqui e pode roubar, roubar.
    proximo_objetivo(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    % Senão, andar até a cidade do próximo objetivo.
    proximo_objetivo(Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo(Cidade, CidadeObjetivo, ProximaCidade),
    !.
ladrao_action(_, _, nada).


% --- Memoria inicial

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)).

% Mapa tratado como grafo nao direcionado: salva ida e volta.
lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).


% --- Escolhas do preload

% Tesouro com menos requisitos totais (contando dependencias recursivas).
escolher_tesouro(Tesouro) :-
    findall(Quantidade-T,
        quantidade_requisitos_tesouro(T, Quantidade),
        Pares),
    keysort(Pares, [_MenorQuantidade-Tesouro | _]).

quantidade_requisitos_tesouro(Tesouro, Quantidade) :-
    tesouro_conhecido(Tesouro, _Cidade, Requisitos),
    requisitos_totais(Requisitos, Todos),
    length(Todos, Quantidade).

requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Req,
        requisito_recursivo(Requisitos, Req),
        Todos),
    sort(Todos, TodosUnicos).

requisito_recursivo(Requisitos, Req) :-
    member(Req, Requisitos).
requisito_recursivo(Requisitos, ReqIndireto) :-
    member(Req, Requisitos),
    item_conhecido(Req, _Cidade, SubRequisitos),
    requisito_recursivo(SubRequisitos, ReqIndireto).

%!  escolher_identidade(+Suspeitos, -LadraoID) is det.
%
%   Prefere a identidade cujos prefixos de aparencia ainda combinem com muitos
%   suspeitos, reduzindo a utilidade das primeiras pistas reveladas.
escolher_identidade(Suspeitos, LadraoID) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_MelhorPontuacao-LadraoID | _]).

% Aceita os dois formatos de suspeito usados nos cenarios do projeto.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _Nome, aparencia(Aparencia)), Suspeitos),
    !.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, aparencia(Aparencia)), Suspeitos).

% Soma, sobre cada prefixo da aparencia, quantos suspeitos sao compativeis.
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


% --- Requisitos e proximo objetivo

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    member(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

%!  proximo_objetivo(+Target, +Itens, -ProximoObjeto) is det.
%
%   Busca primeiro o requisito pendente mais profundo; sem pendencias, o
%   proprio tesouro.
proximo_objetivo(Target, Itens, ProximoObjeto) :-
    tesouro_conhecido(Target, _CidadeTesouro, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito(Req, Itens, ProximoObjeto).
proximo_objetivo(Target, _Itens, Target).

% Desce nos requisitos do item ate achar algo roubavel primeiro.
resolver_requisito(Item, Itens, ProximoObjeto) :-
    item_conhecido(Item, _Cidade, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito(Req, Itens, ProximoObjeto).
resolver_requisito(Item, _Itens, Item).

requisito_pendente([Req | _], Itens, Req) :-
    \+ member(Req, Itens),
    !.
requisito_pendente([Req | Resto], Itens, Pendente) :-
    member(Req, Itens),
    requisito_pendente(Resto, Itens, Pendente).

cidade_do_objeto(Objeto, Cidade) :-
    item_conhecido(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_conhecido(Objeto, Cidade, _).


% --- Busca no mapa

proximo_passo(Origem, Destino, ProximaCidade) :-
    caminho_mais_curto(Origem, Destino, [Origem, ProximaCidade | _]).

% BFS no grafo conhecido. Cada elemento da fila e um caminho invertido (barato
% prepender vizinhos na expansao).
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

% Ignora vizinhos ja vistos GLOBALMENTE (em qualquer caminho da fila), nao so
% no caminho atual -- e o que evita a explosao exponencial da BFS.
estender_caminho([Atual | Visitados], JaVistos, NovosCaminhos, NovosVizinhos) :-
    findall(Vizinho,
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        NovosVizinhos),
    findall([Vizinho, Atual | Visitados],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos).
