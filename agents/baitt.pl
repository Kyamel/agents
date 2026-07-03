:- module(baitt, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.
:- dynamic tesouro_isca/1.
:- dynamic itens_isca/1.
:- dynamic disfarce_inicial_feito/0.
:- dynamic disfarces_usados/1.

% ============================================================
% PRELOAD
% ============================================================

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, LadraoID, ObjetivoLadrao) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_conhecido(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_conhecido(Tesouro, Cidade, Requisitos))),
    forall(member(Suspeito, Suspeitos),
           assertz(suspeito_conhecido(Suspeito))),
    escolher_identidade(Suspeitos, LadraoID),
    escolher_tesouro(ObjetivoLadrao),
    assertz(objetivo_atual(ObjetivoLadrao)),
    assertz(disfarces_usados(0)),
    % Escolhe a isca: outro tesouro com menor número de pré-requisitos
    escolher_isca(ObjetivoLadrao).

% ============================================================
% AÇÕES - ordem de prioridade
% ============================================================

% 1. Fuga: já tem o tesouro real
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, Vizinho)) :-
    member(Target, Itens),
    !,
    aresta_conhecida(Cidade, Vizinho).

% 2. Disfarce inicial: logo no começo da partida, antes de qualquer roubo,
%    troca as posições FINAIS da aparência por valores de outro suspeito.
%    Isso inverte a suposição do Marple de que "posições tardias = real".
ladrao_action(_, thief(loc(_), _, aparencia(AS), _Target, Itens, Dsg),
              disfarce([Modificacao])) :-
    Itens = [],                          % ainda não roubou nada
    \+ disfarce_inicial_feito,           % ainda não fez o disfarce inicial
    Dsg > 0,
    disfarces_usados(0),                 % usa só 1 disfarce para o inicial
    escolher_disfarce_final(AS, Modificacao),
    Modificacao \= none,
    !,
    assertz(disfarce_inicial_feito),
    retract(disfarces_usados(_)),
    assertz(disfarces_usados(1)).

% 3. Roubar tesouro real: pré-requisitos satisfeitos
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% 4. Rouba itens da isca ANTES da cadeia real ficar pronta.
%    Objetivo: criar ambiguidade permanente no mp_ready_target do Marple,
%    que exige candidato ÚNICO. Com itens de outra cadeia, sempre haverá
%    2+ tesouros "prontos" ao mesmo tempo, impedindo o fechamento.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(ItemIsca)) :-
    tesouro_isca(Isca),
    itens_isca(ItensIsca),
    % Só faz isso enquanto a cadeia real ainda não está pronta
    \+ prereqs_reais_prontos(Target, Itens),
    % Encontra próximo item da isca ainda não roubado que esteja aqui
    member(ItemIsca, ItensIsca),
    \+ member(ItemIsca, Itens),
    item_conhecido(ItemIsca, Cidade, ReqIsca),
    requisitos_satisfeitos(ReqIsca, Itens),
    % Garante que o item da isca não é da cadeia real
    \+ item_do_objetivo(ItemIsca, Target),
    !.

% 5. Mover para pegar item da isca (se valer o desvio)
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    tesouro_isca(Isca),
    itens_isca(ItensIsca),
    \+ prereqs_reais_prontos(Target, Itens),
    % Próximo item da isca não roubado
    member(ItemIsca, ItensIsca),
    \+ member(ItemIsca, Itens),
    \+ item_do_objetivo(ItemIsca, Target),
    item_conhecido(ItemIsca, CidadeIsca, ReqIsca),
    requisitos_satisfeitos(ReqIsca, Itens),
    % Só desvia se não adiciona mais que 2 passos ao caminho real
    proximo_objetivo(Target, Itens, ObjetivoReal),
    cidade_do_objeto(ObjetivoReal, CidadeReal),
    distancia_bfs(Cidade, CidadeIsca, D1),
    distancia_bfs(CidadeIsca, CidadeReal, D2),
    distancia_bfs(Cidade, CidadeReal, DDireto),
    D1 + D2 - DDireto =< 2,
    !,
    proximo_passo(Cidade, CidadeIsca, ProximaCidade).

% 6. Rouba próximo item da cadeia real
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    proximo_objetivo(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% 7. Move para próximo objetivo (isca ou real, o que for mais urgente)
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    proximo_objetivo(Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo(Cidade, CidadeObjetivo, ProximaCidade),
    !.

ladrao_action(_, _, nada).

% ============================================================
% ESCOLHA DE ISCA
%
% Escolhe outro tesouro com o MENOR número de pré-requisitos diretos.
% Salva apenas os ITENS (não o tesouro em si) que precisamos roubar
% para criar a ambiguidade — não precisamos roubar o tesouro isca,
% só os itens que ele exige.
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
    % Coleta os itens da cadeia da isca (excluindo o tesouro em si)
    tesouro_conhecido(Isca, _, ReqsIsca),
    requisitos_totais(ReqsIsca, TodosItensIsca),
    assertz(itens_isca(TodosItensIsca)),
    !.
escolher_isca(_) :-
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])).

% Verifica se os pré-requisitos REAIS do tesouro alvo já estão prontos
prereqs_reais_prontos(Target, Itens) :-
    tesouro_conhecido(Target, _, Reqs),
    subtract(Reqs, [Target], Prereqs),
    forall(member(P, Prereqs), member(P, Itens)).

% ============================================================
% DISFARCE — troca posições FINAIS da aparência
%
% O Marple confia nas posições tardias (reveladas por último) como
% sendo as mais reais. Esta estratégia troca exatamente essas posições
% por valores de outro suspeito, invertendo a suposição.
% ============================================================

escolher_disfarce_final(AS, trocar(Original, Falso)) :-
    % Filtra atributos reais (não disfarces já ativos)
    findall(A, (member(A, AS), A \= disfarce(_,_)), Reais),
    Reais \= [],
    % Pega o ÚLTIMO atributo real (posição mais tardia = mais confiada pelo Marple)
    last(Reais, Original),
    Original =.. [Functor, ValorAtual],
    % Busca valor alternativo nos OUTROS suspeitos (não a identidade atual)
    valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso),
    Falso =.. [Functor, ValorFalso],
    !.
escolher_disfarce_final(AS, omitir(Original)) :-
    findall(A, (member(A, AS), A \= disfarce(_,_)), Reais),
    Reais \= [],
    last(Reais, Original),
    !.

% Busca um valor diferente para o mesmo functor entre os suspeitos conhecidos
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
% Menor número de requisitos recursivos totais.
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