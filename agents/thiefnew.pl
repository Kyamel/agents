:- module(thiefnew, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.
:- dynamic cidade_atual_mem/1.
:- dynamic cidade_anterior/1.
:- dynamic visitas/2.
:- dynamic cidade_revelada/1.

%!  ladrao_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto, -LadraoID, -ObjetivoLadrao) is det.
%
%   Inicializa a memoria do agente e escolhe identidade/tesouro. Esta variante
%   e otimizada para reduzir tempo em rota e evitar revisitas perigosas.
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

%!  ladrao_action(+Eventos, +EstadoLadrao, -Acao) is det.
%
%   A cada turno atualiza a memoria observavel e escolhe uma acao. Como a
%   engine nao revela locks, a politica tenta reduzir risco indireto: menos
%   revisitas, menos cidades de baixo grau e menos caminho repetido.
ladrao_action(Eventos, thief(loc(Cidade), _, _, Target, Itens, _), Acao) :-
    registrar_observacao(Eventos, Cidade),
    escolher_acao(Cidade, Target, Itens, Acao),
    !.
ladrao_action(_, _, nada).


% --- Politica de acao

%!  escolher_acao(+Cidade, +Target, +Itens, -Acao) is det.
%
%   Prioridade: fugir se ja venceu, roubar se ha algo util na cidade, senao
%   mover para o melhor proximo objeto pelo custo ajustado de rota.
escolher_acao(Cidade, Target, Itens, move(Cidade, Vizinho)) :-
    member(Target, Itens),
    melhor_saida(Cidade, Vizinho),
    !.
escolher_acao(Cidade, Target, Itens, roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
escolher_acao(Cidade, Target, Itens, roubar(Item)) :-
    melhor_objeto_na_cidade(Cidade, Target, Itens, Item),
    !.
escolher_acao(Cidade, Target, Itens, move(Cidade, ProximaCidade)) :-
    melhor_objetivo(Cidade, Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo_seguro(Cidade, CidadeObjetivo, ProximaCidade),
    !.
escolher_acao(_, _, _, nada).

%!  melhor_objeto_na_cidade(+Cidade, +Target, +Itens, -Item) is semidet.
%
%   Rouba um item util disponivel na cidade atual. Entre varios, prefere o que
%   desbloqueia mais progresso na cadeia do tesouro.
melhor_objeto_na_cidade(Cidade, Target, Itens, Item) :-
    findall(Score-Obj,
        ( objeto_disponivel(Target, Itens, Obj),
          item_conhecido(Obj, Cidade, Requisitos),
          requisitos_satisfeitos(Requisitos, Itens),
          utilidade_objeto(Target, Obj, Utilidade),
          Score is -Utilidade
        ),
        Pares),
    keysort(Pares, [_-Item | _]).

%!  melhor_objetivo(+Cidade, +Target, +Itens, -Objeto) is semidet.
%
%   Escolhe dinamicamente o proximo item/tesouro entre todos os objetivos ja
%   desbloqueados, usando custo de rota com penalidade de risco.
melhor_objetivo(Cidade, Target, Itens, Objeto) :-
    findall(Score-Obj,
        ( objeto_disponivel(Target, Itens, Obj),
          cidade_do_objeto(Obj, CidadeObj),
          caminho_melhor(Cidade, CidadeObj, Caminho, CustoRota),
          utilidade_objeto(Target, Obj, Utilidade),
          length(Caminho, Tamanho),
          Score is CustoRota + Tamanho * 2 - Utilidade
        ),
        Pares),
    keysort(Pares, [_-Objeto | _]).

%!  objeto_disponivel(+Target, +Itens, -Objeto) is nondet.
%
%   Gera itens necessarios ainda nao coletados cujos requisitos ja foram
%   satisfeitos. O tesouro tambem vira candidato quando ja pode ser roubado.
objeto_disponivel(Target, Itens, Target) :-
    \+ member(Target, Itens),
    tesouro_conhecido(Target, _Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).
objeto_disponivel(Target, Itens, Item) :-
    item_necessario(Target, Item),
    \+ member(Item, Itens),
    item_conhecido(Item, _Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).

%!  utilidade_objeto(+Target, +Objeto, -Utilidade) is det.
%
%   Da bonus a objetos que aparecem como requisito direto de varios pontos da
%   cadeia; isso ajuda o guloso a nao pegar apenas o mais perto sem progresso.
utilidade_objeto(Target, Objeto, Utilidade) :-
    findall(1,
        ( requisito_de_alguem(Target, Objeto)
        ; Target = Objeto
        ),
        Usos),
    length(Usos, N),
    Utilidade is N * 6.

requisito_de_alguem(Target, Objeto) :-
    tesouro_conhecido(Target, _Cidade, Requisitos),
    member(Objeto, Requisitos).
requisito_de_alguem(Target, Objeto) :-
    item_necessario(Target, Item),
    item_conhecido(Item, _Cidade, Requisitos),
    member(Objeto, Requisitos).


% --- Memoria observavel

%!  registrar_observacao(+Eventos, +Cidade) is det.
%
%   Atualiza cidades reveladas por roubos e a memoria de posicao/visitas. A
%   lista de locks nao e observavel pela engine, entao nao aparece aqui.
registrar_observacao(Eventos, Cidade) :-
    forall(member(roubo(_, CidadeRoubo, _), Eventos),
           lembrar_cidade_revelada(CidadeRoubo)),
    registrar_posicao(Cidade).

lembrar_cidade_revelada(Cidade) :-
    cidade_revelada(Cidade),
    !.
lembrar_cidade_revelada(Cidade) :-
    assertz(cidade_revelada(Cidade)).

registrar_posicao(Cidade) :-
    cidade_atual_mem(Cidade),
    !.
registrar_posicao(Cidade) :-
    retract(cidade_atual_mem(Anterior)),
    !,
    retractall(cidade_anterior(_)),
    assertz(cidade_anterior(Anterior)),
    incrementar_visita(Cidade),
    assertz(cidade_atual_mem(Cidade)).
registrar_posicao(Cidade) :-
    incrementar_visita(Cidade),
    assertz(cidade_atual_mem(Cidade)).

incrementar_visita(Cidade) :-
    retract(visitas(Cidade, N0)),
    !,
    N is N0 + 1,
    assertz(visitas(Cidade, N)).
incrementar_visita(Cidade) :-
    assertz(visitas(Cidade, 1)).

visitas_da_cidade(Cidade, N) :-
    visitas(Cidade, N),
    !.
visitas_da_cidade(_, 0).


% --- Memoria inicial

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)),
    retractall(cidade_atual_mem(_)),
    retractall(cidade_anterior(_)),
    retractall(visitas(_, _)),
    retractall(cidade_revelada(_)).

lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).


% --- Escolhas do preload

%!  escolher_tesouro(-Tesouro) is det.
%
%   Escolhe tesouro com menor custo estrutural: poucos roubos e rota estimada
%   curta entre os objetos da cadeia.
escolher_tesouro(Tesouro) :-
    findall(Score-T,
        score_tesouro(T, Score),
        Pares),
    keysort(Pares, [_-Tesouro | _]).

score_tesouro(Tesouro, Score) :-
    tesouro_conhecido(Tesouro, CidadeTesouro, Requisitos),
    requisitos_totais(Requisitos, Todos),
    length(Todos, QtdRequisitos),
    findall(Cidade,
        ( member(Obj, Todos),
          cidade_do_objeto(Obj, Cidade)
        ),
        CidadesItens),
    distancia_media_ate(CidadeTesouro, CidadesItens, DistMedia),
    grau(CidadeTesouro, GrauTesouro),
    Score is QtdRequisitos * 20 + DistMedia * 3 - GrauTesouro.

distancia_media_ate(_Cidade, [], 0) :- !.
distancia_media_ate(Cidade, Cidades, Media) :-
    findall(D,
        ( member(Outra, Cidades),
          caminho_mais_curto_simples(Cidade, Outra, Caminho),
          length(Caminho, L),
          D is L - 1
        ),
        Distancias),
    sum_list(Distancias, Soma),
    length(Distancias, N),
    Media is Soma / N.

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

item_necessario(Target, Item) :-
    tesouro_conhecido(Target, _Cidade, Requisitos),
    requisito_recursivo(Requisitos, Item).

%!  escolher_identidade(+Suspeitos, -LadraoID) is det.
%
%   Escolhe a aparencia mais ambigua nos prefixos revelados pelos primeiros
%   roubos.
escolher_identidade(Suspeitos, LadraoID) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_-LadraoID | _]).

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _Nome, aparencia(Aparencia)), Suspeitos),
    !.
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


% --- Requisitos e localizacao

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    member(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

cidade_do_objeto(Objeto, Cidade) :-
    item_conhecido(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_conhecido(Objeto, Cidade, _).


% --- Busca no mapa com custo de risco

proximo_passo_seguro(Origem, Destino, ProximaCidade) :-
    caminho_melhor(Origem, Destino, [Origem, ProximaCidade | _], _).

%!  caminho_melhor(+Origem, +Destino, -Caminho, -Score) is semidet.
%
%   Busca de custo uniforme (Dijkstra): expande sempre o caminho de menor custo
%   acumulado. Como o custo de cada cidade e fixo e positivo, o primeiro caminho
%   a alcancar o destino ja e o de menor risco, sem enumerar todos os caminhos.
caminho_melhor(Origem, Destino, Caminho, Score) :-
    ucs([0-[Origem]], [], Destino, CaminhoInvertido, Score),
    reverse(CaminhoInvertido, Caminho).

ucs([Custo-[Destino | Resto] | _], _Fechados, Destino, [Destino | Resto], Custo) :-
    !.
ucs([_Custo-[Atual | _] | Resto], Fechados, Destino, Caminho, Score) :-
    memberchk(Atual, Fechados),
    !,
    ucs(Resto, Fechados, Destino, Caminho, Score).
ucs([Custo-[Atual | Visitados] | Resto], Fechados, Destino, Caminho, Score) :-
    findall(Custo2-[Vizinho, Atual | Visitados],
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, Fechados),
          custo_cidade(Vizinho, IncCusto),
          Custo2 is Custo + IncCusto
        ),
        NovosCaminhos),
    append(Resto, NovosCaminhos, FilaBruta),
    keysort(FilaBruta, FilaOrdenada),
    ucs(FilaOrdenada, [Atual | Fechados], Destino, Caminho, Score).

% Custo de entrar numa cidade: mesmo peso de score_caminho/2 (12 + penalidade).
custo_cidade(Cidade, Custo) :-
    penalidade_cidade(Cidade, Penalidade),
    Custo is 12 + Penalidade.

%   Menor caminho puro (BFS) para quando so a distancia importa.
caminho_mais_curto_simples(Origem, Destino, Caminho) :-
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
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        NovosVizinhos),
    findall([Vizinho, Atual | Visitados],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos).

score_caminho([_Origem | Resto], Score) :-
    length(Resto, Passos),
    findall(Penalidade,
        ( member(Cidade, Resto),
          penalidade_cidade(Cidade, Penalidade)
        ),
        Penalidades),
    sum_list(Penalidades, PenalidadeTotal),
    Score is Passos * 12 + PenalidadeTotal.

penalidade_cidade(Cidade, Penalidade) :-
    visitas_da_cidade(Cidade, Visitas),
    penalidade_grau(Cidade, GrauPenalty),
    penalidade_retorno(Cidade, RetornoPenalty),
    penalidade_revelada(Cidade, ReveladaPenalty),
    Penalidade is Visitas * 9 + GrauPenalty + RetornoPenalty + ReveladaPenalty.

penalidade_grau(Cidade, 12) :-
    grau(Cidade, Grau),
    Grau =< 1,
    !.
penalidade_grau(Cidade, 5) :-
    grau(Cidade, 2),
    !.
penalidade_grau(Cidade, -3) :-
    grau(Cidade, Grau),
    Grau >= 4,
    !.
penalidade_grau(_, 0).

penalidade_retorno(Cidade, 7) :-
    cidade_anterior(Cidade),
    !.
penalidade_retorno(_, 0).

penalidade_revelada(Cidade, 6) :-
    cidade_revelada(Cidade),
    !.
penalidade_revelada(_, 0).

%!  melhor_saida(+Cidade, -Vizinho) is semidet.
%
%   Depois de roubar o tesouro, qualquer saida vence. Preferimos uma saida com
%   maior mobilidade e menor historico de revisita.
melhor_saida(Cidade, Vizinho) :-
    findall(Score-V,
        ( aresta_conhecida(Cidade, V),
          penalidade_cidade(V, P),
          grau(V, Grau),
          Score is P - Grau * 2
        ),
        Pares),
    keysort(Pares, [_-Vizinho | _]).

grau(Cidade, Grau) :-
    findall(Vizinho, aresta_conhecida(Cidade, Vizinho), Vizinhos),
    sort(Vizinhos, Unicos),
    length(Unicos, Grau).
