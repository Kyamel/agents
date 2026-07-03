:- module(evasort, [
    ladrao_preload/7,
    ladrao_action/3
]).

% evasort = baitpromax + EVASÃO ATIVA CONTRA O shortestd.
%
% Ideia: o ladrão roda DENTRO de si a mesma predição do shortestd
% (`cidade_predita_para_bloqueio`) para saber EXATAMENTE qual cidade o detetive
% vai trancar neste turno, e se recusa a pisar nela.
%
% Por que dá para prever com exatidão: pelo timing da engine, ladrão e detetive
% leem os MESMOS eventos no mesmo turno (o roubo do turno atual só entra na lista
% depois que ambos já agiram — Interactor: emitirEvento põe no slot 1,
% getEvents lê o slot 2). Logo, com o mesmo mapa e os mesmos eventos, a predição
% do ladrão coincide com a trava real do detetive.
%
% E por que evitar exatamente o passo previsto salva: o shortestd tranca o
% PRIMEIRO passo da rota (cidade_de_armadilha). Como o ladrão anda antes e a
% trava é aplicada depois, ela cai na célula em que o ladrão acabou de pisar —
% e ele morre ao SAIR dela no turno seguinte. Se o ladrão não pisar ali (desvia
% para outro vizinho rumo ao mesmo objetivo), a trava fecha uma célula vazia.
%
% A réplica do shortestd usa memória PRÓPRIA (prefixo sd_) e um espelho das
% travas já feitas (sd_lock) — nunca toca no módulo shortestd real, então
% funciona mesmo quando o adversário É o shortestd (mesmo processo Prolog).

:- use_module('baitpromax.pl', []).

:- dynamic sd_edge/2.
:- dynamic sd_item/3.
:- dynamic sd_treasure/3.
:- dynamic sd_lock/1.


% ============================================================
% PRELOAD — popula a memória da réplica com o MESMO mapa e delega o resto ao
% baitpromax (que carrega baittpro/baitt).
% ============================================================

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    limpar_sd,
    forall(member(adj(A, B), Grafo),
           ( assertz(sd_edge(A, B)), assertz(sd_edge(B, A)) )),
    forall(member(item(I, C, R), Itens), assertz(sd_item(I, C, R))),
    forall(member(tesouro(T, C, R), Tesouros), assertz(sd_treasure(T, C, R))),
    baipromax_preload(Grafo, Suspeitos, Itens, Tesouros, LadraoID, ObjetivoLadrao).

baipromax_preload(Grafo, Suspeitos, Itens, Tesouros, LadraoID, ObjetivoLadrao) :-
    baitpromax:ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
                              LadraoID, ObjetivoLadrao).

limpar_sd :-
    retractall(sd_edge(_, _)),
    retractall(sd_item(_, _, _)),
    retractall(sd_treasure(_, _, _)),
    retractall(sd_lock(_)).


% ============================================================
% AÇÃO
% ============================================================

ladrao_action(Eventos, Estado, Acao) :-
    Estado = thief(loc(Cidade), _, _, Target, Itens, _),
    baitpromax:ladrao_action(Eventos, Estado, AcaoBase),
    trava_prevista(Eventos, LockPrevisto),   % o que o shortestd vai fechar agora
    ( AcaoBase = move(Cidade, Passo),
      LockPrevisto \== nenhum,
      Passo == LockPrevisto,                 % pisaríamos justo na célula travada
      rota_evasiva(Cidade, Target, Itens, Passo, PassoNovo)
    -> Acao = move(Cidade, PassoNovo)
    ;  Acao = AcaoBase
    ).

% Calcula a trava do shortestd para este turno e a espelha (assim como o detetive
% real faz `lembrar_lock`), para que a predição dos próximos turnos considere as
% cidades já trancadas — igual ao `\+ known_lock` do original.
trava_prevista(Eventos, Lock) :-
    ( sd_predict(Eventos, Cidade)
    -> Lock = Cidade,
       ( sd_lock(Cidade) -> true ; assertz(sd_lock(Cidade)) )
    ;  Lock = nenhum
    ).

% Desvia da célula travada (Passo) APENAS se houver um vizinho alternativo de
% MESMO comprimento até o MESMO destino que o passo travado buscava. Custo zero:
% contra o shortestd fura a trava; contra qualquer outro detetive não atrasa nada
% nem muda o destino (evita o zigue-zague que empatava as partidas). Se não há
% alternativa mínima, seguimos o passo canônico (arriscar é melhor que empatar).
rota_evasiva(Cidade, Target, Itens, Passo, PassoNovo) :-
    destino_do_passo(Cidade, Target, Itens, Passo, Destino),
    baitt:distancia_bfs(Cidade, Destino, DAtual),
    DAlvo is DAtual - 1,
    findall(W,
        ( baitt:aresta_conhecida(Cidade, W),
          W \== Passo,
          baitt:distancia_bfs(W, Destino, DAlvo)
        ),
        Alternativas),
    Alternativas \== [],
    last(Alternativas, PassoNovo).

% Descobre para qual cidade o passo (travado) do baitpromax estava indo: testa os
% mesmos candidatos que o baitpromax usa (objetivo diversificado e, depois, o
% canônico) e fica com aquele para o qual Passo é de fato um passo de caminho
% mínimo. Assim a rota alternativa termina exatamente onde o baitpromax queria.
destino_do_passo(Cidade, Target, Itens, Passo, Destino) :-
    candidato_destino(Cidade, Target, Itens, Destino),
    baitt:distancia_bfs(Cidade, Destino, DA),
    DA > 0,
    baitt:distancia_bfs(Passo, Destino, DP),
    DP =:= DA - 1,
    !.

candidato_destino(Cidade, Target, Itens, Destino) :-
    \+ member(Target, Itens),
    baitpromax:destino_diversificado(Cidade, Target, Itens, Destino).
candidato_destino(_Cidade, Target, Itens, Destino) :-
    \+ member(Target, Itens),
    baitt:proximo_objetivo(Target, Itens, Objeto),
    baitt:cidade_do_objeto(Objeto, Destino).


% ============================================================
% RÉPLICA FIEL DA PREDIÇÃO DO shortestd (memória sd_, travas espelhadas)
% Copiada de agents/shortestd.pl; qualquer mudança lá deve refletir aqui.
% ============================================================

sd_predict(Eventos, Cidade) :-
    sd_ultimo_roubo(Eventos, _Item, CidadeAtual),
    sd_itens_roubados(Eventos, Roubados),
    sd_melhor_alvo_previsto(CidadeAtual, Roubados, _Obj, CidadeAlvo),
    sd_cidade_de_armadilha(CidadeAtual, CidadeAlvo, Cidade),
    \+ sd_lock(Cidade),
    !.
sd_predict(Eventos, Cidade) :-
    Eventos \= [],
    sd_ultimo_roubo(Eventos, _Item, CidadeAtual),
    \+ sd_lock(CidadeAtual),
    Cidade = CidadeAtual,
    !.
sd_predict([], Cidade) :-
    sd_primeira_cidade_provavel(Cidade),
    \+ sd_lock(Cidade).

sd_cidade_de_armadilha(Origem, Origem, Origem) :- !.
sd_cidade_de_armadilha(Origem, Destino, Cidade) :-
    sd_caminho_mais_curto(Origem, Destino, [Origem, Cidade | _]).

sd_melhor_alvo_previsto(CidadeAtual, Roubados, Objeto, CidadeObjeto) :-
    findall(Score-Obj-CidadeObj,
        ( sd_objetivo_disponivel_previsto(Roubados, Obj),
          sd_cidade_do_objeto(Obj, CidadeObj),
          sd_caminho_mais_curto(CidadeAtual, CidadeObj, Caminho),
          length(Caminho, Tamanho),
          sd_dependencia_restante(Obj, Roubados, Restante),
          Score is Tamanho * 10 + Restante * 4
        ),
        Pares),
    keysort(Pares, [_-Objeto-CidadeObjeto | _]).

sd_objetivo_disponivel_previsto(Roubados, Tesouro) :-
    sd_treasure(Tesouro, _Cidade, Requisitos),
    \+ member(Tesouro, Roubados),
    sd_requisitos_satisfeitos(Requisitos, Roubados).
sd_objetivo_disponivel_previsto(Roubados, Item) :-
    sd_item_relevante(Item),
    \+ member(Item, Roubados),
    sd_item(Item, _Cidade, Requisitos),
    sd_requisitos_satisfeitos(Requisitos, Roubados).

sd_item_relevante(Item) :-
    sd_treasure(_Tesouro, _Cidade, Requisitos),
    sd_requisito_recursivo(Requisitos, Item).

sd_dependencia_restante(Objeto, Roubados, Restante) :-
    sd_treasure(Objeto, _Cidade, Requisitos),
    !,
    sd_requisitos_totais(Requisitos, Todos),
    subtract(Todos, Roubados, Pendentes),
    length(Pendentes, Restante).
sd_dependencia_restante(Objeto, Roubados, Restante) :-
    sd_item(Objeto, _Cidade, Requisitos),
    sd_requisitos_totais(Requisitos, Todos),
    subtract(Todos, Roubados, Pendentes),
    length(Pendentes, Restante).

sd_primeira_cidade_provavel(Cidade) :-
    findall(Score-C,
        ( sd_objetivo_disponivel_previsto([], Obj),
          sd_cidade_do_objeto(Obj, C),
          sd_grau(C, Grau),
          sd_dependencia_restante(Obj, [], Restante),
          Score is Restante * 10 - Grau
        ),
        Pares),
    keysort(Pares, [_-Cidade | _]).

sd_ultimo_roubo([roubo(Item, Cidade, _) | _], Item, Cidade) :- !.
sd_ultimo_roubo([_ | Eventos], Item, Cidade) :-
    sd_ultimo_roubo(Eventos, Item, Cidade).

sd_itens_roubados(Eventos, Roubados) :-
    findall(Item, member(roubo(Item, _Cidade, _), Eventos), Itens),
    sort(Itens, Roubados).

sd_requisitos_satisfeitos([], _).
sd_requisitos_satisfeitos([Req | Resto], Itens) :-
    member(Req, Itens),
    sd_requisitos_satisfeitos(Resto, Itens).

sd_requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Req, sd_requisito_recursivo(Requisitos, Req), Todos),
    sort(Todos, TodosUnicos).

sd_requisito_recursivo(Requisitos, Req) :-
    member(Req, Requisitos).
sd_requisito_recursivo(Requisitos, ReqIndireto) :-
    member(Req, Requisitos),
    sd_item(Req, _Cidade, SubRequisitos),
    sd_requisito_recursivo(SubRequisitos, ReqIndireto).

sd_cidade_do_objeto(Objeto, Cidade) :-
    sd_item(Objeto, Cidade, _),
    !.
sd_cidade_do_objeto(Objeto, Cidade) :-
    sd_treasure(Objeto, Cidade, _).

sd_grau(Cidade, Grau) :-
    findall(V, sd_edge(Cidade, V), Vs),
    sort(Vs, Unicos),
    length(Unicos, Grau).

sd_caminho_mais_curto(Origem, Destino, Caminho) :-
    sd_bfs([[Origem]], [Origem], Destino, CaminhoInvertido),
    reverse(CaminhoInvertido, Caminho).

sd_bfs([[Destino | Resto] | _], _Visitados, Destino, [Destino | Resto]) :-
    !.
sd_bfs([CaminhoAtual | OutrosCaminhos], Visitados, Destino, Caminho) :-
    sd_estender_caminho(CaminhoAtual, Visitados, NovosCaminhos, NovosVizinhos),
    append(Visitados, NovosVizinhos, VisitadosAtualizado),
    append(OutrosCaminhos, NovosCaminhos, FilaAtualizada),
    sd_bfs(FilaAtualizada, VisitadosAtualizado, Destino, Caminho).

sd_estender_caminho([Atual | Visitados], JaVistos, NovosCaminhos, NovosVizinhos) :-
    findall(Vizinho,
        ( sd_edge(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        NovosVizinhos),
    findall([Vizinho, Atual | Visitados],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos).
