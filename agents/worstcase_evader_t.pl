% ============================================================
% LADRAO: worstcase_evader_t
%
% Ladrao evasivo por pior caso. Assume o pior modelo de bloqueio: depois
% de cada roubo, o detetive fecha um vizinho da cidade roubada por turno,
% em ordem de grau. Preve essas cidades e as evita como passagem — o que,
% de quebra, produz rotas menos obvias contra qualquer detetive. Antes de
% cada movimento atualiza a previsao de bloqueios; so precisa que a cidade
% ATUAL esteja livre para sair (a partida termina antes da proxima acao do
% detetive apos o roubo do tesouro).
% Robusto contra bloqueadores reativos; conservador, pode gastar passos
% extras contornando ameacas.
% ============================================================

:- module(worstcase_evader_t, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- use_module(library(lists)).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.
:- dynamic plano_disfarce/1.
:- dynamic disfarce_feito/0.
:- dynamic item_isca/1.
:- dynamic bloqueio_previsto/1.
:- dynamic cidade_ja_bloqueada/1.
:- dynamic fila_bloqueios/1.
:- dynamic cidade_anterior/1.

usar_disfarce(true).

% Este agente assume o pior caso para bloqueios: depois de cada roubo,
% neighborblockd fecha um vizinho por turno, em ordem de grau decrescente.
% Evitar essas cidades também produz rotas menos óbvias contra os demais.

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_conhecido(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_conhecido(Tesouro, Cidade, Requisitos))),
    forall(member(Suspeito, Suspeitos),
           assertz(suspeito_conhecido(Suspeito))),
    escolher_identidade_e_disfarce(Suspeitos, LadraoID, PlanoDisfarce),
    assertz(plano_disfarce(PlanoDisfarce)),
    escolher_tesouro_seguro(ObjetivoLadrao),
    assertz(objetivo_atual(ObjetivoLadrao)),
    escolher_isca_segura(ObjetivoLadrao),
    assertz(fila_bloqueios([])).

ladrao_action(_Eventos, Estado, Acao) :-
    atualizar_bloqueio_previsto,
    once(decidir_acao(Estado, Acao)).


% --- Política

% Após obter o tesouro basta sair da cidade. A engine termina a partida antes
% da próxima ação do detetive, portanto só a cidade atual precisa estar livre.
decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    memberchk(Target, Itens),
    vizinho_de_fuga(Cidade, Proxima),
    registrar_movimento(Cidade),
    !.

decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _),
             roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    iniciar_fila_bloqueios(Cidade),
    !.

% Um prefixo falso coerente basta para o primeiro mandato identificar uma
% pessoa diferente. As mudanças necessárias são feitas numa única ação.
decidir_acao(thief(_, _, _, _, Itens, Dsg), disfarce(Modificacoes)) :-
    usar_disfarce(true),
    Itens == [],
    \+ disfarce_feito,
    Dsg > 0,
    plano_disfarce(Modificacoes),
    Modificacoes \= [],
    length(Modificacoes, Quantidade),
    Quantidade =< Dsg,
    assertz(disfarce_feito),
    !.

% A isca física é oportunista: se a rota passar por um item-raiz exclusivo de
% outro tesouro, ele é roubado para poluir a inferência sem pagar um desvio.
decidir_acao(thief(loc(Cidade), _, _, _, Itens, _), roubar(Isca)) :-
    item_isca(Isca),
    \+ memberchk(Isca, Itens),
    item_conhecido(Isca, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    iniciar_fila_bloqueios(Cidade),
    !.

% Rouba qualquer folha disponível da cadeia real quando já está na cidade.
decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    item_real_disponivel(Target, Itens, Item, Cidade),
    iniciar_fila_bloqueios(Cidade),
    !.

decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    escolher_destino(Cidade, Target, Itens, CidadeDestino),
    caminho_seguro(Cidade, CidadeDestino, [Cidade, Proxima | _]),
    registrar_movimento(Cidade),
    !.

% Se a previsão conservadora ficar sem rota, ainda tenta um vizinho que não
% tenha sido efetivamente previsto como fechado.
decidir_acao(thief(loc(Cidade), _, _, _, _, _), move(Cidade, Proxima)) :-
    vizinhos_unicos(Cidade, Vizinhos),
    member(Proxima, Vizinhos),
    \+ bloqueio_previsto(Proxima),
    registrar_movimento(Cidade),
    !.

decidir_acao(_, nada).


% --- Seleção do alvo e da isca

% Com um único bloqueio ativo, cidades de grau 2 voltam a ser escapáveis:
% basta sair antes de o bloqueio seguinte substituir o atual. Assim, a cadeia
% de menor tamanho é a melhor base média contra todos os detetives.
escolher_tesouro_seguro(Tesouro) :-
    tesouro_conhecido(ouro_do_banco, _, _),
    Tesouro = ouro_do_banco,
    !.
escolher_tesouro_seguro(Tesouro) :-
    findall(Custo-T,
        ( tesouro_conhecido(T, _, _),
          cadeia_itens_tesouro(T, Cadeia),
          length(Cadeia, Custo)
        ),
        Opcoes),
    keysort(Opcoes, [_-Tesouro | _]),
    !.

escolher_isca_segura(Target) :-
    findall(Grau-I,
        ( tesouro_conhecido(Outro, _, _),
          Outro \= Target,
          item_da_cadeia(Outro, I),
          \+ item_da_cadeia(Target, I),
          item_conhecido(I, Cidade, Requisitos),
          Requisitos == [],
          grau_cidade(Cidade, Grau),
          Grau >= 3
        ),
        Opcoes),
    keysort(Opcoes, Ordenadas),
    reverse(Ordenadas, [_-Isca | _]),
    assertz(item_isca(Isca)),
    !.
escolher_isca_segura(_).


% --- Próximo objeto

item_real_disponivel(Target, Itens, Item, Cidade) :-
    item_da_cadeia(Target, Item),
    \+ memberchk(Item, Itens),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).

destino_disponivel(Target, Itens, Target, Cidade) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).
destino_disponivel(Target, Itens, Item, Cidade) :-
    item_real_disponivel(Target, Itens, Item, Cidade).
% Distância domina a escolha; grau alto desempata porque dá mais rotas de
% escape depois do roubo.
escolher_destino(Cidade, Target, Itens, CidadeDestino) :-
    findall(Score-CidadeObjeto,
        ( destino_disponivel(Target, Itens, _Objeto, CidadeObjeto),
          caminho_seguro(Cidade, CidadeObjeto, Caminho),
          length(Caminho, Tamanho),
          grau_cidade(CidadeObjeto, Grau),
          Score is Tamanho * 10 - Grau
        ),
        Opcoes),
    keysort(Opcoes, [_-CidadeDestino | _]).


% --- Modelo do bloqueador

% Esta atualização ocorre no início do turno do ladrão. Se há uma fila ativa,
% uma ação do detetive aconteceu desde a última decisão e fechou exatamente
% uma cidade ainda aberta.
atualizar_bloqueio_previsto :-
    retract(fila_bloqueios(Fila)),
    consumir_primeiro_aberto(Fila, Restante),
    assertz(fila_bloqueios(Restante)),
    !.
atualizar_bloqueio_previsto.

consumir_primeiro_aberto([], []).
consumir_primeiro_aberto([Cidade | Resto], Restante) :-
    cidade_ja_bloqueada(Cidade),
    !,
    consumir_primeiro_aberto(Resto, Restante).
consumir_primeiro_aberto([Cidade | Resto], Resto) :-
    retractall(bloqueio_previsto(_)),
    assertz(cidade_ja_bloqueada(Cidade)),
    assertz(bloqueio_previsto(Cidade)).

iniciar_fila_bloqueios(Cidade) :-
    vizinhos_em_ordem_de_bloqueio(Cidade, Fila),
    retractall(fila_bloqueios(_)),
    assertz(fila_bloqueios(Fila)).

vizinhos_em_ordem_de_bloqueio(Cidade, Fila) :-
    findall(Score-Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          \+ cidade_ja_bloqueada(Vizinho),
          grau_cidade(Vizinho, Grau),
          Score is -Grau
        ),
        Pares),
    keysort(Pares, Ordenados),
    pares_valores(Ordenados, Fila).

pares_valores([], []).
pares_valores([_-Valor | Pares], [Valor | Valores]) :-
    pares_valores(Pares, Valores).

proximo_bloqueio(Cidade) :-
    fila_bloqueios([Cidade | _]).


% --- Rotas

caminho_seguro(Origem, Destino, Caminho) :-
    bfs_seguro([[Origem]], [Origem], Destino, Reverso),
    reverse(Reverso, Caminho).

bfs_seguro([[Destino | Resto] | _], _, Destino, [Destino | Resto]) :-
    !.
bfs_seguro([Atual | Fila], Visitados, Destino, Caminho) :-
    estender_caminho_seguro(Atual, Visitados, Novos, NovasCidades),
    append(Visitados, NovasCidades, Visitados1),
    append(Fila, Novos, Fila1),
    bfs_seguro(Fila1, Visitados1, Destino, Caminho).

estender_caminho_seguro([Cidade | Resto], Visitados,
                        NovosCaminhos, NovasCidades) :-
    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          \+ memberchk(Vizinho, Visitados),
          \+ bloqueio_previsto(Vizinho),
          \+ proximo_bloqueio(Vizinho)
        ),
        Novas0),
    sort(Novas0, NovasCidades),
    findall([Vizinho, Cidade | Resto],
        member(Vizinho, NovasCidades),
        NovosCaminhos).

vizinho_de_fuga(Cidade, Proxima) :-
    vizinhos_unicos(Cidade, Vizinhos),
    findall(Grau-V,
        ( member(V, Vizinhos),
          \+ bloqueio_previsto(V),
          grau_cidade(V, Grau)
        ),
        Opcoes),
    keysort(Opcoes, Ordenadas),
    reverse(Ordenadas, [_-Proxima | _]).

registrar_movimento(Cidade) :-
    retractall(cidade_anterior(_)),
    assertz(cidade_anterior(Cidade)).


% --- Disfarce e identidade

escolher_identidade_e_disfarce(Suspeitos, Id, Modificacoes) :-
    member(procurado(Id, aparencia(Real)), Suspeitos),
    member(procurado(IdFalso, aparencia(Falsa)), Suspeitos),
    IdFalso \= Id,
    duas_primeiras(Falsa, F1, F2),
    findall(OutroId,
        ( member(procurado(OutroId, aparencia(Aparencia)), Suspeitos),
          prefixo_compativel([F1, F2], Aparencia)
        ),
        Compativeis),
    length(Compativeis, Quantidade),
    Quantidade >= 1,
    Quantidade =< 2,
    \+ memberchk(Id, Compativeis),
    duas_primeiras(Real, R1, R2),
    modificacoes_diferentes([R1-F1, R2-F2], Modificacoes),
    Modificacoes \= [],
    !.
escolher_identidade_e_disfarce(Suspeitos, Id, []) :-
    aparencia_suspeito(Id, Suspeitos, _).

duas_primeiras([A, B | _], A, B).

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, aparencia(Aparencia)), Suspeitos).
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _, aparencia(Aparencia)), Suspeitos).

modificacoes_diferentes([], []).
modificacoes_diferentes([Real-Falsa | Pares], Modificacoes) :-
    Real == Falsa,
    !,
    modificacoes_diferentes(Pares, Modificacoes).
modificacoes_diferentes([Real-Falsa | Pares],
                        [trocar(Real, Falsa) | Modificacoes]) :-
    modificacoes_diferentes(Pares, Modificacoes).

prefixo_compativel([], _).
prefixo_compativel([A | As], [A | Bs]) :-
    prefixo_compativel(As, Bs).


% --- Requisitos e grafo

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    memberchk(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

cadeia_itens_tesouro(Tesouro, Itens) :-
    tesouro_conhecido(Tesouro, _, Requisitos),
    findall(Item,
        ( requisito_recursivo(Requisitos, Item),
          item_conhecido(Item, _, _)
        ),
        Todos),
    sort(Todos, Itens).

item_da_cadeia(Target, Item) :-
    tesouro_conhecido(Target, _, Requisitos),
    requisito_recursivo(Requisitos, Item),
    item_conhecido(Item, _, _).

requisito_recursivo(Requisitos, Req) :-
    member(Req, Requisitos).
requisito_recursivo(Requisitos, ReqIndireto) :-
    member(Req, Requisitos),
    item_conhecido(Req, _, SubRequisitos),
    requisito_recursivo(SubRequisitos, ReqIndireto).

grau_cidade(Cidade, Grau) :-
    vizinhos_unicos(Cidade, Vizinhos),
    length(Vizinhos, Grau).

vizinhos_unicos(Cidade, Vizinhos) :-
    findall(V, aresta_conhecida(Cidade, V), Repetidos),
    sort(Repetidos, Vizinhos).

lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).


% --- Memória

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)),
    retractall(plano_disfarce(_)),
    retractall(disfarce_feito),
    retractall(item_isca(_)),
    retractall(bloqueio_previsto(_)),
    retractall(cidade_ja_bloqueada(_)),
    retractall(fila_bloqueios(_)),
    retractall(cidade_anterior(_)).
