:- module(chaost, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- use_module(library(lists)).
:- use_module(library(random)).

:- dynamic aresta/2.
:- dynamic item_mem/3.
:- dynamic tesouro_mem/3.
:- dynamic plano_disfarce/1.
:- dynamic disfarce_feito/0.
:- dynamic saida_inicial_feita/0.
:- dynamic modo_empate/0.
:- dynamic acoes_feitas/1.
:- dynamic cidade_anterior/1.
:- dynamic ultimo_roubo_proprio/1.
:- dynamic bloqueio_previsto/1.
:- dynamic cidade_ja_bloqueada/1.
:- dynamic fila_bloqueios/1.

limite_turnos(30).
margem_de_tempo(0).
bait(codigo_alarme).


% --- Preload

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, Id, Objetivo) :-
    limpar,
    forall(member(adj(A, B), Grafo), guardar_aresta(A, B)),
    forall(member(item(I, C, R), Itens), assertz(item_mem(I, C, R))),
    forall(member(tesouro(T, C, R), Tesouros),
           assertz(tesouro_mem(T, C, R))),
    escolher_identidade(Suspeitos, Id, Plano),
    assertz(plano_disfarce(Plano)),
    escolher_objetivo(Objetivo),
    assertz(acoes_feitas(0)),
    assertz(fila_bloqueios([])).


% --- Entrada

ladrao_action(_Eventos, Estado, Acao) :-
    atualizar_bloqueio_previsto,
    once(decidir(Estado, Acao)),
    incrementar_acoes.

decidir(_, nada) :-
    modo_empate,
    !.

% shortestd fecha Kings Cross no primeiro turno. Se o ladrão nasceu lá, sai
% antes de gastar o turno do disfarce e deixa o bloqueio para trás.
decidir(thief(loc(kings_cross), _, _, _, Itens, _),
        move(kings_cross, Proxima)) :-
    Itens == [],
    \+ disfarce_feito,
    \+ saida_inicial_feita,
    escolher_saida_inicial(Proxima),
    assertz(saida_inicial_feita),
    !.

decidir(thief(_, _, _, _, Itens, Dsg), disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_feito,
    plano_disfarce(Modificacoes),
    Modificacoes \= [],
    length(Modificacoes, N),
    N =< Dsg,
    assertz(disfarce_feito),
    !.

decidir(thief(_, _, _, _, Itens, _), nada) :-
    Itens == [],
    \+ disfarce_feito,
    ativar_empate,
    !.

% Uma previsão de bloqueio na cidade atual pede uma rodada de espera. Se a
% vitória deixar de caber no prazo, a regra seguinte congela definitivamente.
decidir(thief(loc(Cidade), _, _, _, _, _), nada) :-
    bloqueio_previsto(Cidade),
    retractall(bloqueio_previsto(_)),
    !.

decidir(Estado, nada) :-
    vitoria_inviavel(Estado),
    ativar_empate,
    !.

decidir(thief(loc(Cidade), _, _, Target, Itens, _),
        move(Cidade, Proxima)) :-
    memberchk(Target, Itens),
    passo_fuga(Cidade, Proxima),
    lembrar_movimento(Cidade),
    !.

% Só rouba o alvo depois da isca. Quando a obra de arte fica pronta, o ouro
% também fica pronto e Marple perde a unicidade necessária para fechar.
decidir(thief(loc(Cidade), _, _, Target, Itens, _), roubar(Target)) :-
    bait(Bait),
    memberchk(Bait, Itens),
    tesouro_mem(Target, Cidade, Requisitos),
    satisfeitos(Requisitos, Itens),
    iniciar_fila(Cidade),
    assertz(ultimo_roubo_proprio(Cidade)),
    !.

decidir(thief(loc(Cidade), _, _, _, Itens, _), roubar(Bait)) :-
    bait(Bait),
    \+ memberchk(Bait, Itens),
    item_mem(Bait, Cidade, Requisitos),
    satisfeitos(Requisitos, Itens),
    iniciar_fila(Cidade),
    assertz(ultimo_roubo_proprio(Cidade)),
    !.

decidir(thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    item_real_disponivel(Target, Itens, Item, Cidade),
    iniciar_fila(Cidade),
    assertz(ultimo_roubo_proprio(Cidade)),
    !.

decidir(thief(loc(Cidade), _, _, Target, Itens, _),
        move(Cidade, Proxima)) :-
    escolher_objeto_nao_guloso(Cidade, Target, Itens, Destino),
    passo_variavel(Cidade, Destino, Proxima),
    lembrar_movimento(Cidade),
    !.

decidir(_, nada) :-
    ativar_empate.


% --- Modo de empate

vitoria_inviavel(thief(loc(Cidade), _, _, Target, Itens, _)) :-
    acoes_feitas(Gastas),
    limite_turnos(Limite),
    Restantes is Limite - Gastas,
    custo_restante(Cidade, Target, Itens, Custo),
    margem_de_tempo(Margem),
    Custo + Margem > Restantes,
    !.
vitoria_inviavel(thief(loc(Cidade), _, _, Target, Itens, _)) :-
    \+ existe_progresso(Cidade, Target, Itens).

existe_progresso(Cidade, Target, Itens) :-
    memberchk(Target, Itens),
    passo_fuga(Cidade, _),
    !.
existe_progresso(Cidade, Target, Itens) :-
    bait(Bait),
    memberchk(Bait, Itens),
    tesouro_mem(Target, Cidade, R),
    satisfeitos(R, Itens),
    !.
existe_progresso(Cidade, _Target, Itens) :-
    bait(Bait),
    \+ memberchk(Bait, Itens),
    item_mem(Bait, Cidade, R),
    satisfeitos(R, Itens),
    !.
existe_progresso(Cidade, Target, Itens) :-
    item_real_disponivel(Target, Itens, _, Cidade),
    !.
existe_progresso(Cidade, Target, Itens) :-
    escolher_objeto_nao_guloso(Cidade, Target, Itens, Destino),
    passo_variavel(Cidade, Destino, _).

ativar_empate :-
    modo_empate,
    !.
ativar_empate :-
    assertz(modo_empate).

incrementar_acoes :-
    retract(acoes_feitas(N)),
    N1 is N + 1,
    assertz(acoes_feitas(N1)).


% --- Custo otimista restante

custo_restante(_, Target, Itens, 1) :-
    memberchk(Target, Itens),
    !.
custo_restante(Cidade, Target, Itens, Custo) :-
    bait(Bait),
    memberchk(Bait, Itens),
    tesouro_mem(Target, CidadeT, Requisitos),
    satisfeitos(Requisitos, Itens),
    !,
    distancia(Cidade, CidadeT, D),
    Custo is D + 2.
custo_restante(Cidade, Target, Itens, Custo) :-
    findall(C,
        ( proxima_coleta(Target, Itens, Item, CidadeItem),
          distancia(Cidade, CidadeItem, D),
          custo_restante(CidadeItem, Target, [Item | Itens], Depois),
          C is D + 1 + Depois
        ),
        Custos),
    min_list(Custos, Custo).

proxima_coleta(_Target, Itens, Bait, Cidade) :-
    bait(Bait),
    \+ memberchk(Bait, Itens),
    item_mem(Bait, Cidade, R),
    satisfeitos(R, Itens).
proxima_coleta(Target, Itens, Item, Cidade) :-
    item_real_disponivel(Target, Itens, Item, Cidade).


% --- Escolha de alvo, coleta e isca

escolher_objetivo(obra_de_arte) :-
    tesouro_mem(obra_de_arte, _, _),
    item_mem(codigo_alarme, _, _),
    !.
escolher_objetivo(Target) :-
    findall(N-T,
        ( tesouro_mem(T, _, _),
          cadeia(T, Cadeia),
          length(Cadeia, N)
        ),
        Opcoes),
    keysort(Opcoes, [_-Target | _]).

item_real_disponivel(Target, Itens, Item, Cidade) :-
    item_da_cadeia(Target, Item),
    \+ memberchk(Item, Itens),
    item_mem(Item, Cidade, R),
    satisfeitos(R, Itens),
    % Não confirma a primeira previsão de shortestd antes de produzir pistas.
    ( Itens == [] -> Item \= radio_policial ; true ).

objeto_disponivel(_Target, Itens, Bait, Cidade) :-
    bait(Bait),
    \+ memberchk(Bait, Itens),
    item_mem(Bait, Cidade, R),
    satisfeitos(R, Itens).
objeto_disponivel(Target, Itens, Target, Cidade) :-
    bait(Bait),
    memberchk(Bait, Itens),
    tesouro_mem(Target, Cidade, R),
    satisfeitos(R, Itens).
objeto_disponivel(Target, Itens, Item, Cidade) :-
    item_real_disponivel(Target, Itens, Item, Cidade).

% Seleciona aleatoriamente entre opções até um passo acima da melhor. Isso
% mantém eficiência suficiente para 30 turnos sem repetir a previsão gulosa.
escolher_objeto_nao_guloso(Cidade, Target, Itens, Destino) :-
    findall(D-CidadeObjeto,
        ( objeto_disponivel(Target, Itens, _, CidadeObjeto),
          caminho_seguro(Cidade, CidadeObjeto, Caminho),
          length(Caminho, L),
          D is L - 1
        ),
        Pares),
    keysort(Pares, [Min-_ | _]),
    Limite is Min + 1,
    findall(C,
        ( member(D-C, Pares),
          D =< Limite
        ),
        Candidatos0),
    sort(Candidatos0, Candidatos),
    random_member(Destino, Candidatos).

satisfeitos([], _).
satisfeitos([R | Rs], Itens) :-
    memberchk(R, Itens),
    satisfeitos(Rs, Itens).

cadeia(Target, Itens) :-
    tesouro_mem(Target, _, R),
    findall(I,
        ( requisito_recursivo(R, I),
          item_mem(I, _, _)
        ),
        Todos),
    sort(Todos, Itens).

item_da_cadeia(Target, Item) :-
    tesouro_mem(Target, _, R),
    requisito_recursivo(R, Item),
    item_mem(Item, _, _).

requisito_recursivo(R, X) :-
    member(X, R).
requisito_recursivo(R, X) :-
    member(I, R),
    item_mem(I, _, Sub),
    requisito_recursivo(Sub, X).


% --- Disfarce

escolher_identidade(Suspeitos, 9, Plano) :-
    aparencia(9, Suspeitos, [A1, A2, R3, R4, R5]),
    aparencia(1, Suspeitos, [A1, A2, F3, F4 | _]),
    Plano = [trocar(R3, F3), trocar(R4, F4), omitir(R5)],
    !.
escolher_identidade(Suspeitos, Id, Plano) :-
    aparencia(Id, Suspeitos, [A1, A2, R3, R4, R5]),
    aparencia(Outro, Suspeitos, [A1, A2, F3, F4 | _]),
    Outro \= Id,
    R3 \= F3,
    R4 \= F4,
    Plano = [trocar(R3, F3), trocar(R4, F4), omitir(R5)],
    !.
escolher_identidade(Suspeitos, Id, []) :-
    aparencia(Id, Suspeitos, _).

aparencia(Id, Suspeitos, A) :-
    member(procurado(Id, aparencia(A)), Suspeitos),
    !.
aparencia(Id, Suspeitos, A) :-
    member(procurado(Id, _, aparencia(A)), Suspeitos).


% --- Bloqueio de vizinhos

atualizar_bloqueio_previsto :-
    retract(fila_bloqueios(Fila)),
    consumir_bloqueio(Fila, Resto),
    assertz(fila_bloqueios(Resto)),
    !.
atualizar_bloqueio_previsto.

consumir_bloqueio([], []).
consumir_bloqueio([C | Cs], Resto) :-
    cidade_ja_bloqueada(C),
    !,
    consumir_bloqueio(Cs, Resto).
consumir_bloqueio([C | Cs], Cs) :-
    retractall(bloqueio_previsto(_)),
    assertz(cidade_ja_bloqueada(C)),
    assertz(bloqueio_previsto(C)).

iniciar_fila(Cidade) :-
    findall(Score-V,
        ( aresta(Cidade, V),
          \+ cidade_ja_bloqueada(V),
          grau(V, G),
          Score is -G
        ),
        Pares),
    keysort(Pares, Ordenados),
    valores(Ordenados, Fila),
    retractall(fila_bloqueios(_)),
    assertz(fila_bloqueios(Fila)).

valores([], []).
valores([_-V | Ps], [V | Vs]) :-
    valores(Ps, Vs).

proximo_bloqueio(C) :-
    fila_bloqueios([C | _]).


% --- Rotas variáveis

passo_variavel(Origem, Destino, Proxima) :-
    findall(Custo-V,
        ( aresta(Origem, V),
          \+ bloqueio_previsto(V),
          \+ proximo_bloqueio(V),
          distancia(V, Destino, D),
          Custo is D
        ),
        Opcoes),
    keysort(Opcoes, [Melhor-_ | _]),
    Limite = Melhor,
    findall(V,
        ( member(C-V, Opcoes),
          C =< Limite,
          nao_retorna(V)
        ),
        Variaveis0),
    ( Variaveis0 == []
    -> findall(V, member(_-V, Opcoes), Variaveis)
    ;  Variaveis = Variaveis0
    ),
    random_member(Proxima, Variaveis).

passo_fuga(Cidade, Proxima) :-
    findall(G-V,
        ( aresta(Cidade, V),
          \+ bloqueio_previsto(V),
          \+ proximo_bloqueio(V),
          grau(V, G)
        ),
        Opcoes),
    keysort(Opcoes, Ordenadas),
    reverse(Ordenadas, [_-Proxima | _]).

escolher_saida_inicial(Proxima) :-
    findall(G-V,
        ( aresta(kings_cross, V),
          V \= liverpool_street,
          grau(V, G)
        ),
        Opcoes),
    keysort(Opcoes, Ordenadas),
    reverse(Ordenadas, [_-Proxima | _]).

nao_retorna(Cidade) :-
    ( cidade_anterior(Anterior) -> Cidade \= Anterior ; true ).

lembrar_movimento(Cidade) :-
    retractall(cidade_anterior(_)),
    assertz(cidade_anterior(Cidade)).

caminho_seguro(Origem, Destino, Caminho) :-
    bfs([[Origem]], [Origem], Destino, Reverso),
    reverse(Reverso, Caminho).

bfs([[Destino | Resto] | _], _, Destino, [Destino | Resto]) :-
    !.
bfs([Atual | Fila], Visitados, Destino, Caminho) :-
    Atual = [Cidade | _],
    findall(V,
        ( aresta(Cidade, V),
          \+ memberchk(V, Visitados),
          \+ bloqueio_previsto(V),
          \+ proximo_bloqueio(V)
        ),
        Novas0),
    sort(Novas0, Novas),
    findall([V | Atual], member(V, Novas), Extensoes),
    append(Visitados, Novas, Visitados1),
    append(Fila, Extensoes, Fila1),
    bfs(Fila1, Visitados1, Destino, Caminho).

distancia(Origem, Destino, D) :-
    bfs_d([[Origem, 0]], [Origem], Destino, D).

bfs_d([[Destino, D] | _], _, Destino, D) :-
    !.
bfs_d([[Cidade, D0] | Fila], Visitados, Destino, D) :-
    D1 is D0 + 1,
    findall(V,
        ( aresta(Cidade, V),
          \+ memberchk(V, Visitados)
        ),
        Novas0),
    sort(Novas0, Novas),
    findall([V, D1], member(V, Novas), Entradas),
    append(Visitados, Novas, Visitados1),
    append(Fila, Entradas, Fila1),
    bfs_d(Fila1, Visitados1, Destino, D).

grau(C, G) :-
    findall(V, aresta(C, V), Repetidos),
    sort(Repetidos, Vizinhos),
    length(Vizinhos, G).

guardar_aresta(A, B) :-
    assertz(aresta(A, B)),
    assertz(aresta(B, A)).


% --- Limpeza

limpar :-
    retractall(aresta(_, _)),
    retractall(item_mem(_, _, _)),
    retractall(tesouro_mem(_, _, _)),
    retractall(plano_disfarce(_)),
    retractall(disfarce_feito),
    retractall(saida_inicial_feita),
    retractall(modo_empate),
    retractall(acoes_feitas(_)),
    retractall(cidade_anterior(_)),
    retractall(ultimo_roubo_proprio(_)),
    retractall(bloqueio_previsto(_)),
    retractall(cidade_ja_bloqueada(_)),
    retractall(fila_bloqueios(_)).
