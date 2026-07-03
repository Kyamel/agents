:- module(drawerl, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- use_module(library(lists)).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic objetivo_atual/1.
:- dynamic plano_disfarce/1.
:- dynamic disfarce_feito/0.
:- dynamic modo_seguranca/0.
:- dynamic acoes_feitas/1.
:- dynamic bloqueio_previsto/1.
:- dynamic cidade_ja_bloqueada/1.
:- dynamic fila_bloqueios/1.

limite_turnos(30).
margem_seguranca(1).


% --- Inicialização

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_conhecido(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_conhecido(Tesouro, Cidade, Requisitos))),
    escolher_identidade_e_disfarce(Suspeitos, LadraoID, Plano),
    assertz(plano_disfarce(Plano)),
    escolher_objetivo(ObjetivoLadrao),
    assertz(objetivo_atual(ObjetivoLadrao)),
    assertz(acoes_feitas(0)),
    assertz(fila_bloqueios([])).


% --- Laço principal

ladrao_action(_Eventos, Estado, Acao) :-
    atualizar_bloqueio_previsto,
    once(decidir_acao(Estado, Acao)),
    registrar_acao.

decidir_acao(_, nada) :-
    modo_seguranca,
    !.

% O disfarce altera os três atributos finais. Os dois primeiros atributos do
% suspeito 9 ainda deixam três identidades possíveis; os demais passam a
% apontar para o suspeito 1, tornando um mandato posterior inofensivo.
decidir_acao(thief(_, _, _, _, Itens, Dsg), disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_feito,
    plano_disfarce(Modificacoes),
    Modificacoes \= [],
    length(Modificacoes, Quantidade),
    Quantidade =< Dsg,
    assertz(disfarce_feito),
    !.

% Sem disfarces suficientes, não começa o roubo: sem pistas não existe mandato
% legal e ficar parado força o empate.
decidir_acao(thief(_, _, _, _, Itens, _), nada) :-
    Itens == [],
    \+ disfarce_feito,
    ativar_modo_seguranca,
    !.

% Se apenas o modelo de bloqueio acusa perigo imediato, espera uma rodada para
% a única cidade fechada ser substituída. A margem temporal decidirá depois se
% ainda vale retomar a tentativa.
decidir_acao(thief(loc(Cidade), _, _, _, _, _), nada) :-
    bloqueio_previsto(Cidade),
    retractall(bloqueio_previsto(_)),
    !.

% O botão de pânico é irreversível. Depois de acionado, o ladrão nunca tenta
% sair de uma cidade possivelmente fechada.
decidir_acao(Estado, nada) :-
    deve_abortar(Estado),
    ativar_modo_seguranca,
    !.

decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    memberchk(Target, Itens),
    escolher_fuga_segura(Cidade, Proxima),
    !.

decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _),
             roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    iniciar_fila_bloqueios(Cidade),
    !.

decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    item_disponivel(Target, Itens, Item, Cidade),
    iniciar_fila_bloqueios(Cidade),
    !.

decidir_acao(thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    escolher_destino(Cidade, Target, Itens, Destino),
    caminho_seguro(Cidade, Destino, [Cidade, Proxima | _]),
    !.

decidir_acao(_, nada) :-
    ativar_modo_seguranca.


% --- Decisão de abandonar a tentativa de vitória

deve_abortar(thief(loc(Cidade), _, _, Target, Itens, _)) :-
    acoes_feitas(Gastas),
    limite_turnos(Limite),
    Disponiveis is Limite - Gastas,
    custo_otimo_restante(Cidade, Target, Itens, Custo),
    margem_seguranca(Margem),
    Custo + Margem > Disponiveis,
    !.
deve_abortar(thief(loc(Cidade), _, _, Target, Itens, _)) :-
    \+ acao_de_progresso_existe(Cidade, Target, Itens).

acao_de_progresso_existe(Cidade, Target, Itens) :-
    memberchk(Target, Itens),
    escolher_fuga_segura(Cidade, _),
    !.
acao_de_progresso_existe(Cidade, Target, Itens) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
acao_de_progresso_existe(Cidade, Target, Itens) :-
    item_disponivel(Target, Itens, _, Cidade),
    !.
acao_de_progresso_existe(Cidade, Target, Itens) :-
    escolher_destino(Cidade, Target, Itens, Destino),
    caminho_seguro(Cidade, Destino, [Cidade, _ | _]).

ativar_modo_seguranca :-
    modo_seguranca,
    !.
ativar_modo_seguranca :-
    assertz(modo_seguranca).

registrar_acao :-
    retract(acoes_feitas(N)),
    N1 is N + 1,
    assertz(acoes_feitas(N1)).


% --- Custo otimista exato da cadeia restante

% Conta ações do ladrão: movimentos, roubos e o passo final de fuga. Bloqueios
% são ignorados aqui, portanto o valor é um limite inferior seguro.
custo_otimo_restante(_, Target, Itens, 1) :-
    memberchk(Target, Itens),
    !.
custo_otimo_restante(Cidade, Target, Itens, Custo) :-
    tesouro_conhecido(Target, CidadeTesouro, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !,
    distancia(Cidade, CidadeTesouro, D),
    Custo is D + 2.
custo_otimo_restante(Cidade, Target, Itens, Custo) :-
    findall(CustoOpcao,
        ( item_disponivel(Target, Itens, Item, CidadeItem),
          distancia(Cidade, CidadeItem, D),
          custo_otimo_restante(CidadeItem, Target,
                               [Item | Itens], CustoDepois),
          CustoOpcao is D + 1 + CustoDepois
        ),
        Opcoes),
    min_list(Opcoes, Custo).


% --- Objetivos e requisitos

escolher_objetivo(ouro_do_banco) :-
    tesouro_conhecido(ouro_do_banco, _, _),
    !.
escolher_objetivo(Tesouro) :-
    findall(Quantidade-T,
        ( tesouro_conhecido(T, _, _),
          cadeia_itens_tesouro(T, Cadeia),
          length(Cadeia, Quantidade)
        ),
        Opcoes),
    keysort(Opcoes, [_-Tesouro | _]).

item_disponivel(Target, Itens, Item, Cidade) :-
    item_da_cadeia(Target, Item),
    \+ memberchk(Item, Itens),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).

destino_disponivel(Target, Itens, Target, Cidade) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).
destino_disponivel(Target, Itens, Item, Cidade) :-
    item_disponivel(Target, Itens, Item, Cidade).

escolher_destino(Cidade, Target, Itens, Destino) :-
    findall(Score-CidadeObjeto,
        ( destino_disponivel(Target, Itens, _Objeto, CidadeObjeto),
          caminho_seguro(Cidade, CidadeObjeto, Caminho),
          length(Caminho, Tamanho),
          grau_cidade(CidadeObjeto, Grau),
          Score is Tamanho * 10 - Grau
        ),
        Opcoes),
    keysort(Opcoes, [_-Destino | _]).

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


% --- Disfarce de segurança

escolher_identidade_e_disfarce(Suspeitos, 9, Modificacoes) :-
    aparencia_suspeito(9, Suspeitos,
        [A1, A2, OlhosReais, CabeloReal, UltimoReal]),
    aparencia_suspeito(1, Suspeitos,
        [A1, A2, OlhosFalsos, CabeloFalso | _]),
    Modificacoes = [
        trocar(OlhosReais, OlhosFalsos),
        trocar(CabeloReal, CabeloFalso),
        omitir(UltimoReal)
    ],
    !.
escolher_identidade_e_disfarce(Suspeitos, Id, Modificacoes) :-
    aparencia_suspeito(Id, Suspeitos,
        [A1, A2, R3, R4, R5]),
    aparencia_suspeito(IdFalso, Suspeitos,
        [A1, A2, F3, F4 | _]),
    IdFalso \= Id,
    R3 \= F3,
    R4 \= F4,
    Modificacoes = [trocar(R3, F3), trocar(R4, F4), omitir(R5)],
    !.
escolher_identidade_e_disfarce(Suspeitos, Id, []) :-
    aparencia_suspeito(Id, Suspeitos, _).

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, aparencia(Aparencia)), Suspeitos),
    !.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _, aparencia(Aparencia)), Suspeitos).


% --- Modelo conservador do bloqueador de vizinhos

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
    findall(Score-Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          \+ cidade_ja_bloqueada(Vizinho),
          grau_cidade(Vizinho, Grau),
          Score is -Grau
        ),
        Pares),
    keysort(Pares, Ordenados),
    pares_valores(Ordenados, Fila),
    retractall(fila_bloqueios(_)),
    assertz(fila_bloqueios(Fila)).

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
    estender_seguro(Atual, Visitados, Novos, NovasCidades),
    append(Visitados, NovasCidades, Visitados1),
    append(Fila, Novos, Fila1),
    bfs_seguro(Fila1, Visitados1, Destino, Caminho).

estender_seguro([Cidade | Resto], Visitados, Novos, NovasCidades) :-
    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          \+ memberchk(Vizinho, Visitados),
          \+ bloqueio_previsto(Vizinho),
          \+ proximo_bloqueio(Vizinho)
        ),
        Candidatas),
    sort(Candidatas, NovasCidades),
    findall([Vizinho, Cidade | Resto],
        member(Vizinho, NovasCidades),
        Novos).

escolher_fuga_segura(Cidade, Proxima) :-
    findall(Grau-Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          \+ bloqueio_previsto(Vizinho),
          \+ proximo_bloqueio(Vizinho),
          grau_cidade(Vizinho, Grau)
        ),
        Opcoes),
    keysort(Opcoes, Ordenadas),
    reverse(Ordenadas, [_-Proxima | _]).

distancia(Origem, Destino, Distancia) :-
    bfs_distancia([[Origem, 0]], [Origem], Destino, Distancia).

bfs_distancia([[Destino, D] | _], _, Destino, D) :-
    !.
bfs_distancia([[Cidade, D] | Fila], Visitados, Destino, Distancia) :-
    D1 is D + 1,
    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          \+ memberchk(Vizinho, Visitados)
        ),
        Novas0),
    sort(Novas0, Novas),
    findall([Vizinho, D1], member(Vizinho, Novas), Entradas),
    append(Visitados, Novas, Visitados1),
    append(Fila, Entradas, Fila1),
    bfs_distancia(Fila1, Visitados1, Destino, Distancia).

grau_cidade(Cidade, Grau) :-
    findall(V, aresta_conhecida(Cidade, V), Repetidos),
    sort(Repetidos, Vizinhos),
    length(Vizinhos, Grau).

lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).


% --- Memória

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(objetivo_atual(_)),
    retractall(plano_disfarce(_)),
    retractall(disfarce_feito),
    retractall(modo_seguranca),
    retractall(acoes_feitas(_)),
    retractall(bloqueio_previsto(_)),
    retractall(cidade_ja_bloqueada(_)),
    retractall(fila_bloqueios(_)).
