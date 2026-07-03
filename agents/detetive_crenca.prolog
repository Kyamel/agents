:- module(detetive_crenca, [
    detetive_preload/5,
    detetive_action/3
]).

% ============================================================
% COMPATIBILIDADE COM O ENGINE
% ============================================================
%
% Este arquivo assume as acoes:
%   move(Origem, Destino)
%   fechar(Cidade)
%   pedir_mandato(Id, Evidencias)
%   inspecionar
%   nada
%
% E assume eventos no formato roubo(Item, Cidade, Atributos).
% Se a sua versao usar pedir_mandato(Evidencias, Id), altere somente
% a cabeca da terceira clausula de decidir_acao/4.
%
% O estado do detetive pode ter formatos diferentes: o agente procura
% loc(Cidade), mandato(Id) ou mandado(Id) recursivamente no termo recebido.

% ============================================================
% CONFIGURACAO
% ============================================================

% evento      -> fecha a cidade do roubo assim que o evento aparece.
% interceptar -> usa fechamento apenas quando ja esta na cidade prevista.
politica_fechamento(evento).

% true  -> fechar(Cidade) pode mirar qualquer cidade.
% false -> o agente so tenta fechar a cidade em que o detetive esta.
fechamento_remoto(true).

% Quantidade minima de atributos observados que apoiam um suspeito
% antes de tentar pedir um mandato.
min_atributos_mandato(1).

% ============================================================
% MEMORIA
% ============================================================

:- dynamic aresta_d/2.
:- dynamic item_d/3.
:- dynamic tesouro_d/3.
:- dynamic suspeito_d/2.

:- dynamic roubo_visto/4.       % roubo_visto(Seq, Item, Cidade, Atributos)
:- dynamic proxima_seq/1.
:- dynamic idade_sem_evento/1.

:- dynamic mandato_solicitado/1.
:- dynamic cidade_fechada_por_mim/1.

% ============================================================
% PRELOAD
% ============================================================

% Contrato esperado pelo engine:
% detetive_preload(Grafo, Suspeitos, Itens, Tesouros, pronto).
detetive_preload(Grafo, Suspeitos, Itens, Tesouros, pronto) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_d(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_d(Tesouro, Cidade, Requisitos))),
    forall(member(Suspeito, Suspeitos), guardar_suspeito(Suspeito)),
    assertz(proxima_seq(1)),
    assertz(idade_sem_evento(0)).

limpar_memoria :-
    retractall(aresta_d(_, _)),
    retractall(item_d(_, _, _)),
    retractall(tesouro_d(_, _, _)),
    retractall(suspeito_d(_, _)),
    retractall(roubo_visto(_, _, _, _)),
    retractall(proxima_seq(_)),
    retractall(idade_sem_evento(_)),
    retractall(mandato_solicitado(_)),
    retractall(cidade_fechada_por_mim(_)).

lembrar_aresta(A, B) :-
    (aresta_d(A, B) -> true ; assertz(aresta_d(A, B))),
    (aresta_d(B, A) -> true ; assertz(aresta_d(B, A))).

guardar_suspeito(procurado(Id, _Nome, aparencia(Atributos))) :-
    !,
    assertz(suspeito_d(Id, Atributos)).
guardar_suspeito(procurado(Id, aparencia(Atributos))) :-
    !,
    assertz(suspeito_d(Id, Atributos)).
guardar_suspeito(_).

% ============================================================
% ACAO PRINCIPAL
% ============================================================

% O estado do detetive varia entre versoes do engine. Em vez de fixar
% toda a estrutura, cidade_do_detetive/2 procura recursivamente loc(Cidade).
detetive_action(Eventos, EstadoDetetive, Acao) :-
    processar_eventos(Eventos, NovosRoubos),
    atualizar_idade(NovosRoubos),
    cidade_do_detetive(EstadoDetetive, CidadeDetetive),
    decidir_acao(NovosRoubos, EstadoDetetive, CidadeDetetive, Acao),
    !.
detetive_action(_, _, nada).

% 1. Se temos mandato e acreditamos estar sobre o ladrao, inspeciona.
decidir_acao(_, Estado, CidadeDetetive, inspecionar) :-
    melhor_suspeito(Id, _Score),
    tem_mandato(Estado, Id),
    cidade_atual_estimada_ladrao(CidadeLadrao),
    CidadeDetetive == CidadeLadrao,
    !.

% 2. Armadilha imediata: fecha a cidade do roubo recem-observado.
% O seu ladrao atual sempre tenta sair, entao esta clausula testa diretamente
% se ele reage a cidades fechadas.
decidir_acao(Novos, _Estado, CidadeDetetive, fechar(CidadeFechar)) :-
    politica_fechamento(evento),
    ultimo_novo_roubo(Novos, _Item, CidadeEvento, _Atributos),
    cidade_para_fechamento(CidadeDetetive, CidadeEvento, CidadeFechar),
    \+ cidade_fechada_por_mim(CidadeFechar),
    !,
    assertz(cidade_fechada_por_mim(CidadeFechar)).

% 3. Pede mandato usando somente atributos realmente observados e coerentes
% com o candidato. A lista escolhida precisa reduzir os suspeitos a no maximo 2.
decidir_acao(_, _Estado, _CidadeDetetive, pedir_mandato(Id, Evidencias)) :-
    evidencias_para_mandato(Id, Evidencias),
    \+ mandato_solicitado(Id),
    !,
    assertz(mandato_solicitado(Id)).

% 4. Se ja estamos acampados na proxima cidade prevista, fecha essa cidade.
decidir_acao(_, _Estado, CidadeDetetive, fechar(CidadeDetetive)) :-
    proxima_cidade_objetivo(CidadeObjetivo),
    CidadeDetetive == CidadeObjetivo,
    \+ cidade_fechada_por_mim(CidadeDetetive),
    !,
    assertz(cidade_fechada_por_mim(CidadeDetetive)).

% 5. Move para a melhor cidade de interceptacao.
decidir_acao(_, _Estado, CidadeDetetive, move(CidadeDetetive, Proxima)) :-
    cidade_interceptacao(CidadeDetetive, Interceptacao),
    CidadeDetetive \== Interceptacao,
    proximo_passo(CidadeDetetive, Interceptacao, Proxima),
    !.

% 6. No modo remoto, fecha a cidade prevista mesmo sem estar nela.
decidir_acao(_, _Estado, CidadeDetetive, fechar(CidadeFechar)) :-
    fechamento_remoto(true),
    proxima_cidade_objetivo(CidadeObjetivo),
    cidade_para_fechamento(CidadeDetetive, CidadeObjetivo, CidadeFechar),
    \+ cidade_fechada_por_mim(CidadeFechar),
    !,
    assertz(cidade_fechada_por_mim(CidadeFechar)).

decidir_acao(_, _, _, nada).

cidade_para_fechamento(_CidadeDetetive, CidadeAlvo, CidadeAlvo) :-
    fechamento_remoto(true),
    !.
cidade_para_fechamento(CidadeDetetive, _CidadeAlvo, CidadeDetetive).

% ============================================================
% LEITURA FLEXIVEL DO ESTADO
% ============================================================

cidade_do_detetive(Estado, Cidade) :-
    contem_termo(Estado, loc(Cidade)),
    !.

% Procura um subtermo sem depender de sub_term/2.
contem_termo(Termo, Procurado) :-
    Termo = Procurado.
contem_termo(Termo, Procurado) :-
    compound(Termo),
    functor(Termo, _, Aridade),
    entre(1, Aridade, I),
    arg(I, Termo, Filho),
    contem_termo(Filho, Procurado).

entre(I, Max, I) :-
    I =< Max.
entre(I, Max, N) :-
    I < Max,
    I1 is I + 1,
    entre(I1, Max, N).

% Aceita formatos comuns de estado. A memoria dinamica funciona como fallback.
tem_mandato(Estado, Id) :-
    contem_termo(Estado, mandato(Id)),
    !.
tem_mandato(Estado, Id) :-
    contem_termo(Estado, mandado(Id)),
    !.
tem_mandato(_Estado, Id) :-
    mandato_solicitado(Id).

% ============================================================
% EVENTOS E RELOGIO DE CRENCA
% ============================================================

processar_eventos(Eventos, Novos) :-
    findall(roubo(Item, Cidade, Atributos),
        evento_roubo_em(Eventos, Item, Cidade, Atributos),
        Encontrados0),
    sort(Encontrados0, Encontrados),
    registrar_novos(Encontrados, Novos).

% Suporta tanto uma lista direta de roubo/3 quanto eventos embrulhados.
evento_roubo_em(Eventos, Item, Cidade, Atributos) :-
    contem_termo(Eventos, roubo(Item, Cidade, Atributos)),
    is_list(Atributos).

registrar_novos([], []).
registrar_novos([roubo(Item, Cidade, Atributos) | Resto], Novos) :-
    (   roubo_ja_visto(Item)
    ->  Novos = NovosResto
    ;   registrar_roubo(Item, Cidade, Atributos),
        Novos = [roubo(Item, Cidade, Atributos) | NovosResto]
    ),
    registrar_novos(Resto, NovosResto).

roubo_ja_visto(Item) :-
    roubo_visto(_, Item, _, _).

registrar_roubo(Item, Cidade, Atributos) :-
    retract(proxima_seq(Seq)),
    assertz(roubo_visto(Seq, Item, Cidade, Atributos)),
    Seq1 is Seq + 1,
    assertz(proxima_seq(Seq1)).

atualizar_idade([]) :-
    !,
    retract(idade_sem_evento(Idade0)),
    Idade is Idade0 + 1,
    assertz(idade_sem_evento(Idade)).
atualizar_idade(_) :-
    retractall(idade_sem_evento(_)),
    assertz(idade_sem_evento(0)).

ultimo_novo_roubo(Novos, Item, Cidade, Atributos) :-
    last(Novos, roubo(Item, Cidade, Atributos)).

ultimo_roubo(Item, Cidade, Atributos) :-
    findall(Seq-roubo(I, C, A), roubo_visto(Seq, I, C, A), Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    last(Ordenados, _-roubo(Item, Cidade, Atributos)).

itens_roubados(Itens) :-
    findall(Item, roubo_visto(_, Item, _, _), Itens0),
    sort(Itens0, Itens).

% ============================================================
% CRENCA SOBRE IDENTIDADE
% ============================================================

melhor_suspeito(Id, Score) :-
    findall(S-Id0, pontuacao_suspeito(Id0, S), Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    last(Ordenados, Score-Id).

pontuacao_suspeito(Id, Score) :-
    suspeito_d(Id, Aparencia),
    observacoes_atributos(Observacoes),
    pontuar_observacoes(Observacoes, Aparencia, 0, Score).

observacoes_atributos(Observacoes) :-
    findall(Atributo,
        ( roubo_visto(_, _, _, Lista),
          member(Bruto, Lista),
          atributo_visivel(Bruto, Atributo)
        ),
        Observacoes).

% Se o engine expuser o wrapper de disfarce, considera o valor visivel.
atributo_visivel(disfarce(Visivel, _Original), Atributo) :-
    Visivel \== none,
    !,
    atributo_base(Visivel, Atributo).
atributo_visivel(Atributo, Base) :-
    atributo_base(Atributo, Base).

atributo_base(Atributo, Atributo) :-
    compound(Atributo),
    functor(Atributo, Functor, 1),
    Functor \== disfarce,
    !.

pontuar_observacoes([], _, Score, Score).
pontuar_observacoes([Obs | Resto], Aparencia, Acc, Score) :-
    (   memberchk(Obs, Aparencia)
    ->  Acc1 is Acc + 3
    ;   mesmo_functor_na_aparencia(Obs, Aparencia)
    ->  Acc1 is Acc - 1
    ;   Acc1 = Acc
    ),
    pontuar_observacoes(Resto, Aparencia, Acc1, Score).

mesmo_functor_na_aparencia(Obs, Aparencia) :-
    functor(Obs, Functor, 1),
    member(A, Aparencia),
    compound(A),
    functor(A, Functor, 1),
    !.

% Monta uma lista legal de evidencias: atributos observados que pertencem ao
% candidato, ordenados do mais raro para o mais comum. Para assim que restam
% no maximo dois suspeitos compativeis.
evidencias_para_mandato(Id, Evidencias) :-
    melhor_suspeito(Id, _),
    suspeito_d(Id, Aparencia),
    observacoes_atributos(Observacoes0),
    sort(Observacoes0, Observacoes),
    findall(Raridade-A,
        ( member(A, Observacoes),
          memberchk(A, Aparencia),
          raridade_atributo(A, Raridade)
        ),
        Pares),
    keysort(Pares, Ordenados),
    pares_valores(Ordenados, EvidenciasOrdenadas),
    menor_prefixo_para_mandato(EvidenciasOrdenadas, Evidencias),
    min_atributos_mandato(Min),
    length(Evidencias, N),
    N >= Min.

raridade_atributo(Atributo, Quantidade) :-
    findall(Id,
        ( suspeito_d(Id, Aparencia),
          memberchk(Atributo, Aparencia)
        ),
        Ids),
    length(Ids, Quantidade).

pares_valores([], []).
pares_valores([_-V | Resto], [V | Valores]) :-
    pares_valores(Resto, Valores).

menor_prefixo_para_mandato(Lista, Prefixo) :-
    prefixo_crescente(Lista, Prefixo),
    Prefixo \= [],
    suspeitos_compativeis(Prefixo, Ids),
    length(Ids, N),
    N =< 2,
    !.

prefixo_crescente([X | _], [X]).
prefixo_crescente([X | Xs], [X | Ps]) :-
    prefixo_crescente(Xs, Ps).

suspeitos_compativeis(Evidencias, Ids) :-
    findall(Id,
        ( suspeito_d(Id, Aparencia),
          todos_presentes(Evidencias, Aparencia)
        ),
        Ids).

todos_presentes([], _).
todos_presentes([X | Xs], Lista) :-
    memberchk(X, Lista),
    todos_presentes(Xs, Lista).

% ============================================================
% CRENCA SOBRE O TESOURO-ALVO
% ============================================================

melhor_tesouro(Tesouro, Score) :-
    findall(S-T, pontuacao_tesouro(T, S), Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    last(Ordenados, Score-Tesouro).

pontuacao_tesouro(Tesouro, Score) :-
    itens_roubados(Roubados),
    requisitos_do_tesouro(Tesouro, Cadeia),
    length(Cadeia, Tamanho),
    contar_intersecao(Roubados, Cadeia, Acertos),
    contar_estranhos(Roubados, Cadeia, Tesouro, Estranhos),
    Prior is 120 - 4 * Tamanho,
    ScoreBase is Prior + 35 * Acertos - 4 * Estranhos,
    (memberchk(Tesouro, Roubados) -> Score1 is ScoreBase + 1000 ; Score1 = ScoreBase),
    (ultimo_roubo(Ultimo, _, _), memberchk(Ultimo, Cadeia) -> Score is Score1 + 30 ; Score = Score1).

contar_intersecao([], _, 0).
contar_intersecao([X | Xs], Ys, N) :-
    contar_intersecao(Xs, Ys, N0),
    (memberchk(X, Ys) -> N is N0 + 1 ; N = N0).

contar_estranhos([], _, _, 0).
contar_estranhos([X | Xs], Cadeia, Tesouro, N) :-
    contar_estranhos(Xs, Cadeia, Tesouro, N0),
    (X \== Tesouro, \+ memberchk(X, Cadeia) -> N is N0 + 1 ; N = N0).

requisitos_do_tesouro(Tesouro, Requisitos) :-
    tesouro_d(Tesouro, _, Diretos),
    findall(R,
        ( requisito_recursivo(Diretos, [], R),
          R \== Tesouro
        ),
        Todos),
    sort(Todos, Requisitos).

requisito_recursivo(Requisitos, _Visitados, Req) :-
    member(Req, Requisitos).
requisito_recursivo(Requisitos, Visitados, ReqIndireto) :-
    member(Req, Requisitos),
    \+ memberchk(Req, Visitados),
    item_d(Req, _, SubRequisitos),
    requisito_recursivo(SubRequisitos, [Req | Visitados], ReqIndireto).

% ============================================================
% MODELO EXATO DO LADRAO ENVIADO
% ============================================================

% Primeiro tenta prever a isca; se ela nao for aplicavel, usa a cadeia real.
proximo_objetivo_previsto(Tesouro, Roubados, CidadeAtual, Objeto) :-
    objetivo_isca_previsto(Tesouro, Roubados, CidadeAtual, Objeto),
    !.
proximo_objetivo_previsto(Tesouro, Roubados, _CidadeAtual, Objeto) :-
    proximo_objetivo_real(Tesouro, Roubados, Objeto).

objetivo_isca_previsto(Tesouro, Roubados, CidadeAtual, ItemIsca) :-
    \+ prerequisitos_reais_prontos(Tesouro, Roubados),
    escolher_isca_prevista(Tesouro, Isca),
    requisitos_do_tesouro(Isca, ItensIsca),
    member(ItemIsca, ItensIsca),
    \+ memberchk(ItemIsca, Roubados),
    \+ item_do_tesouro(ItemIsca, Tesouro),
    item_d(ItemIsca, CidadeIsca, RequisitosIsca),
    requisitos_satisfeitos(RequisitosIsca, Roubados),
    proximo_objetivo_real(Tesouro, Roubados, ObjetivoReal),
    cidade_do_objeto(ObjetivoReal, CidadeReal),
    distancia_bfs(CidadeAtual, CidadeIsca, D1),
    distancia_bfs(CidadeIsca, CidadeReal, D2),
    distancia_bfs(CidadeAtual, CidadeReal, Direto),
    D1 + D2 - Direto =< 2,
    !.

escolher_isca_prevista(Tesouro, Isca) :-
    findall(N-T,
        ( tesouro_d(T, _, Requisitos),
          T \== Tesouro,
          remover_elemento(T, Requisitos, SemProprio),
          length(SemProprio, N)
        ),
        Pares),
    Pares \= [],
    keysort(Pares, [_-Isca | _]).

remover_elemento(_, [], []).
remover_elemento(X, [Y | Ys], Resto) :-
    (X == Y -> remover_elemento(X, Ys, Resto)
    ; Resto = [Y | Rs], remover_elemento(X, Ys, Rs)).

prerequisitos_reais_prontos(Tesouro, Roubados) :-
    tesouro_d(Tesouro, _, Requisitos),
    remover_elemento(Tesouro, Requisitos, Prerequisitos),
    requisitos_satisfeitos(Prerequisitos, Roubados).

proximo_objetivo_real(Tesouro, Roubados, Proximo) :-
    tesouro_d(Tesouro, _, Requisitos),
    requisito_pendente(Requisitos, Roubados, Req),
    !,
    resolver_requisito(Req, Roubados, Proximo).
proximo_objetivo_real(Tesouro, _, Tesouro).

resolver_requisito(Item, Roubados, Proximo) :-
    item_d(Item, _, Requisitos),
    requisito_pendente(Requisitos, Roubados, Req),
    !,
    resolver_requisito(Req, Roubados, Proximo).
resolver_requisito(Item, _, Item).

requisito_pendente([Req | _], Roubados, Req) :-
    \+ memberchk(Req, Roubados),
    !.
requisito_pendente([_ | Resto], Roubados, Req) :-
    requisito_pendente(Resto, Roubados, Req).

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Roubados) :-
    memberchk(Req, Roubados),
    requisitos_satisfeitos(Resto, Roubados).

item_do_tesouro(Item, Tesouro) :-
    requisitos_do_tesouro(Tesouro, Requisitos),
    memberchk(Item, Requisitos).

cidade_do_objeto(Objeto, Cidade) :-
    item_d(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_d(Objeto, Cidade, _).

% ============================================================
% POSICAO E INTERCEPTACAO
% ============================================================

proxima_cidade_objetivo(CidadeObjetivo) :-
    melhor_tesouro(Tesouro, _),
    itens_roubados(Roubados),
    cidade_base_inferencia(CidadeBase),
    proximo_objetivo_previsto(Tesouro, Roubados, CidadeBase, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo).

cidade_base_inferencia(Cidade) :-
    ultimo_roubo(_, Cidade, _),
    !.
cidade_base_inferencia(Cidade) :-
    cidade_central(Cidade).

cidade_atual_estimada_ladrao(CidadeEstimada) :-
    ultimo_roubo(_, CidadeRoubo, _),
    melhor_tesouro(Tesouro, _),
    itens_roubados(Roubados),
    proximo_objetivo_previsto(Tesouro, Roubados, CidadeRoubo, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    caminho_mais_curto(CidadeRoubo, CidadeObjetivo, Caminho),
    idade_sem_evento(Idade),
    elemento_limitado(Idade, Caminho, CidadeEstimada),
    !.
cidade_atual_estimada_ladrao(Cidade) :-
    cidade_central(Cidade).

% Antes do primeiro roubo nao existe localizacao observada. O melhor ponto de
% espera e uma cidade que minimiza a soma das distancias ate os primeiros
% objetivos provaveis.
cidade_central(Cidade) :-
    findall(Soma-C,
        ( cidade_conhecida(C),
          soma_distancias_objetivos(C, Soma)
        ),
        Pares),
    Pares \= [],
    keysort(Pares, [_-Cidade | _]).

cidade_conhecida(Cidade) :- aresta_d(Cidade, _).

soma_distancias_objetivos(Cidade, Soma) :-
    findall(D,
        ( tesouro_d(T, _, _),
          proximo_objetivo_real(T, [], Objeto),
          cidade_do_objeto(Objeto, CidadeObjeto),
          distancia_bfs(Cidade, CidadeObjeto, D)
        ),
        Distancias),
    somar_lista(Distancias, Soma).

somar_lista([], 0).
somar_lista([X | Xs], Soma) :-
    somar_lista(Xs, Resto),
    Soma is X + Resto.

% Prefere acampar no proximo objeto. Se a rota possuir um ponto que o
% detetive alcanca antes do ladrao, usa esse ponto como interceptacao.
cidade_interceptacao(CidadeDetetive, Interceptacao) :-
    ultimo_roubo(_, CidadeRoubo, _),
    melhor_tesouro(Tesouro, _),
    itens_roubados(Roubados),
    proximo_objetivo_previsto(Tesouro, Roubados, CidadeRoubo, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    caminho_mais_curto(CidadeRoubo, CidadeObjetivo, Caminho),
    idade_sem_evento(Idade),
    sufixo_a_partir(Idade, Caminho, CaminhoRestante),
    ponto_alcancavel_antes(CidadeDetetive, CaminhoRestante, 0, Interceptacao),
    !.
cidade_interceptacao(_CidadeDetetive, Interceptacao) :-
    proxima_cidade_objetivo(Interceptacao),
    !.
cidade_interceptacao(_CidadeDetetive, Interceptacao) :-
    cidade_central(Interceptacao).

% Exige chegada estritamente anterior. Chegar empatado geralmente nao basta,
% pois o ladrao pode sair antes da proxima inspecao.
ponto_alcancavel_antes(CidadeDetetive, [Cidade | _], EtaLadrao, Cidade) :-
    distancia_bfs(CidadeDetetive, Cidade, EtaDetetive),
    EtaDetetive < EtaLadrao,
    !.
ponto_alcancavel_antes(CidadeDetetive, [_ | Resto], Eta, Cidade) :-
    Eta1 is Eta + 1,
    ponto_alcancavel_antes(CidadeDetetive, Resto, Eta1, Cidade).

sufixo_a_partir(0, Lista, Lista) :- !.
sufixo_a_partir(_, [], []) :- !.
sufixo_a_partir(N, [_ | Resto], Sufixo) :-
    N1 is N - 1,
    sufixo_a_partir(N1, Resto, Sufixo).

elemento_limitado(N, Lista, Elemento) :-
    sufixo_a_partir(N, Lista, Sufixo),
    (Sufixo = [Elemento | _] -> true ; last(Lista, Elemento)).

% ============================================================
% BFS
% ============================================================

proximo_passo(Origem, Destino, Proxima) :-
    caminho_mais_curto(Origem, Destino, [Origem, Proxima | _]).

caminho_mais_curto(Origem, Destino, Caminho) :-
    bfs([[Origem]], [Origem], Destino, Invertido),
    reverse(Invertido, Caminho).

bfs([[Destino | Resto] | _], _, Destino, [Destino | Resto]) :- !.
bfs([Atual | Fila], Visitados, Destino, Caminho) :-
    estender_caminho(Atual, Visitados, NovosCaminhos, NovosVertices),
    append(Visitados, NovosVertices, Visitados1),
    append(Fila, NovosCaminhos, Fila1),
    bfs(Fila1, Visitados1, Destino, Caminho).

estender_caminho([Cidade | Caminho], Visitados, NovosCaminhos, NovosVertices) :-
    findall(Vizinho,
        ( aresta_d(Cidade, Vizinho),
          \+ memberchk(Vizinho, Visitados)
        ),
        Vizinhos0),
    sort(Vizinhos0, NovosVertices),
    construir_caminhos(NovosVertices, [Cidade | Caminho], NovosCaminhos).

construir_caminhos([], _, []).
construir_caminhos([V | Vs], Caminho, [[V | Caminho] | Resto]) :-
    construir_caminhos(Vs, Caminho, Resto).

distancia_bfs(Origem, Destino, 0) :-
    Origem == Destino,
    !.
distancia_bfs(Origem, Destino, Distancia) :-
    bfs_dist([[Origem, 0]], [Origem], Destino, Distancia).

bfs_dist([[Destino, D] | _], _, Destino, D) :- !.
bfs_dist([[Cidade, D] | Fila], Visitados, Destino, Distancia) :-
    D1 is D + 1,
    findall(V,
        ( aresta_d(Cidade, V),
          \+ memberchk(V, Visitados)
        ),
        Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    montar_niveis(Vizinhos, D1, Novos),
    append(Visitados, Vizinhos, Visitados1),
    append(Fila, Novos, Fila1),
    bfs_dist(Fila1, Visitados1, Destino, Distancia).

montar_niveis([], _, []).
montar_niveis([V | Vs], D, [[V, D] | Resto]) :-
    montar_niveis(Vs, D, Resto).