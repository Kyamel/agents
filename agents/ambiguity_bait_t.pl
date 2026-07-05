% ============================================================
% LADRAO: ambiguity_bait_t
%
% Ladrao de ambiguidade e isca. Alvo = tesouro de menor cadeia de
% pre-requisitos. Identidade = suspeito de aparencia mais ambigua, e no
% primeiro turno gasta todo o disfarce trocando os atributos-chave por
% valores de outro suspeito, aparentando uma identidade diferente e
% dificultando o mandato. Escolhe automaticamente um tesouro secundario e
% coleta seus itens quando o desvio de rota e pequeno, confundindo o
% detetive sobre o objetivo real. Diversifica a rota: entre itens a
% distancia equivalente, escolhe um alternativo para o detetive nao
% antecipar a proxima cidade obrigatoria.
% ============================================================

:- module(ambiguity_bait_t, [
    ladrao_preload/7,
    ladrao_action/3
]).


:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic tesouro_isca/1.
:- dynamic itens_isca/1.
:- dynamic disfarce_inicial_feito/0.
:- dynamic disfarces_usados/1.
:- dynamic plano_disfarce_forte/3.
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
    escolher_identidade(Suspeitos, LadraoID),
    preparar_planos_disfarce_forte(Suspeitos, LadraoID),
    escolher_tesouro(ObjetivoLadrao),
    assertz(disfarces_usados(0)),
    configurar_bait_strategy(ObjetivoLadrao).

% ============================================================
% AÇÃO (diversificação de objetivo)
% ============================================================
%
% Deixa acao_base decidir. Só interferimos quando a decisão é um DESLOCAMENTO e
% estamos em modo "cadeia real" (não fuga, não isca). Aí redirecionamos o
% objetivo. Disfarce, roubo prioritário, isca, e fuga passam intactos.

ladrao_action(Eventos, Estado, Acao) :-
    Estado = thief(loc(Cidade), _, _, Target, Itens, _),
    acao_base(Eventos, Estado, AcaoBase),
    ajustar_acao_cadeia(
        Cidade,
        Target,
        Itens,
        AcaoBase,
        Acao
    ).

% Quando a ação base é um deslocamento da cadeia real, tenta
% redirecioná-la para outro objetivo pendente.
ajustar_acao_cadeia(
    Cidade,
    Target,
    Itens,
    move(Cidade, PassoCanonico),
    Acao
) :-
    modo_cadeia_real(Cidade, Target, Itens),
    !,
    acao_cadeia_real(
        Cidade,
        Target,
        Itens,
        PassoCanonico,
        Acao
    ).

% Disfarces, roubos, fuga, isca e movimentos que não pertencem
% à cadeia real são mantidos sem alteração.
ajustar_acao_cadeia(_, _, _, Acao, Acao).

modo_cadeia_real(Cidade, Target, Itens) :-
    \+ member(Target, Itens),
    \+ cidade_isca_ativa(Cidade, Target, Itens, _).

acao_cadeia_real(Cidade, Target, Itens, _PassoCanonico, roubar(Item)) :-
    objetivo_pendente(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
acao_cadeia_real(Cidade, Target, Itens, _PassoCanonico, move(Cidade, Passo)) :-
    destino_diversificado(Cidade, Target, Itens, CidadeDiv),
    !,
    proximo_passo(Cidade, CidadeDiv, Passo).
acao_cadeia_real(Cidade, _Target, _Itens, PassoCanonico, move(Cidade, PassoCanonico)).

destino_diversificado(Cidade, Target, Itens, CidadeDiv) :-
    proximo_objetivo(Target, Itens, ObjCanonico),
    cidade_do_objeto(ObjCanonico, CidadeCanon),
    distancia_bfs(Cidade, CidadeCanon, DCanon),
    findall(DAlt-CidadeAlt,
        ( objetivo_pendente(Target, Itens, ObjAlt),
          ObjAlt \== ObjCanonico,
          cidade_do_objeto(ObjAlt, CidadeAlt),
          CidadeAlt \== CidadeCanon,
          distancia_bfs(Cidade, CidadeAlt, DAlt),
          DAlt =< DCanon
        ),
        Pares),
    Pares \== [],
    keysort(Pares, Ordenados),
    Ordenados = [MenorD-_ | _],
    findall(C, member(MenorD-C, Ordenados), Cidades),
    last(Cidades, CidadeDiv).

objetivo_pendente(Target, Itens, Folha) :-
    tesouro_conhecido(Target, _, Requisitos),
    member(Req, Requisitos),
    Req \== Target,
    \+ member(Req, Itens),
    resolver_requisito(Req, Itens, Folha).

cidade_isca_ativa(Cidade, Target, Itens, CidadeIsca) :-
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
    !.

% ============================================================
% Ordem de prioridade de decisões
% ============================================================

% Antes do primeiro roubo, procura o melhor plano forte que
% possa ser executado com os pontos de disfarce disponíveis.
acao_base(_, thief(_, _, aparencia(AS), _, Itens, Dsg),
          disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_forte_feito,
    melhor_plano_disfarce_forte(
        Dsg,
        AS,
        Modificacoes,
        Quantidade
    ),
    marcar_disfarce_feito(Quantidade),
    !.

%  Fuga
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, Vizinho)) :-
    member(Target, Itens),
    !,
    aresta_conhecida(Cidade, Vizinho).

% Fallback: quando nenhuma identidade-isca produz um plano forte, usa todo o
% orçamento disponível para alterar os primeiros atributos que serão revelados.
acao_base(_, thief(loc(_), _, aparencia(AS), _Target, Itens, Dsg),
          disfarce(Modificacoes)) :-
    Itens = [],
    \+ disfarce_inicial_feito,
    disfarces_usados(0),
    planejar_disfarce_fallback(
        AS,
        Dsg,
        Modificacoes
    ),
    Modificacoes \= [],
    length(Modificacoes, Quantidade),
    !,
    assertz(disfarce_inicial_feito),
    retract(disfarces_usados(_)),
    assertz(disfarces_usados(Quantidade)).

% Roubar tesouro real
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% Rouba itens da isca
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(ItemIsca)) :-
    tesouro_isca(_Isca),
    itens_isca(ItensIsca),
    \+ prereqs_reais_prontos(Target, Itens),
    member(ItemIsca, ItensIsca),
    \+ member(ItemIsca, Itens),
    item_conhecido(ItemIsca, Cidade, ReqIsca),
    requisitos_satisfeitos(ReqIsca, Itens),
    \+ item_do_objetivo(ItemIsca, Target),
    !.

% Mover para pegar item da isca
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
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

% Rouba próximo item da cadeia real
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    proximo_objetivo(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% Move para próximo objetivo
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    proximo_objetivo(Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo(Cidade, CidadeObjetivo, ProximaCidade),
    !.

acao_base(_, _, nada).

% ============================================================
% ESTRATÉGIA DE ISCA
% ============================================================
%
% Escolhe um tesouro secundario apenas a partir dos tesouros e
% requisitos recebidos no preload.

configurar_bait_strategy(Target) :-
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
configurar_bait_strategy(_) :-
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])).

prereqs_reais_prontos(Target, Itens) :-
    tesouro_conhecido(Target, _, Reqs),
    subtract(Reqs, [Target], Prereqs),
    forall(member(P, Prereqs), member(P, Itens)).

% ============================================================
% DISFARCE 
% ============================================================

planejar_disfarce_fallback(AS, PontosDisponiveis, Modificacoes) :-
    PontosDisponiveis > 0,
    atributos_reais(AS, Reais),
    maplist(modificacao_fallback, Reais, Candidatas),
    quantidade_limitada(
        PontosDisponiveis,
        Candidatas,
        Quantidade
    ),
    prefixo_tamanho(Candidatas, Quantidade, Modificacoes).

atributos_reais(AS, Reais) :-
    exclude(atributo_disfarcado, AS, Reais).

atributo_disfarcado(disfarce(_, _)).

modificacao_fallback(Original, trocar(Original, Falso)) :-
    Original =.. [Functor, ValorAtual],
    valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso),
    Falso =.. [Functor, ValorFalso],
    !.
modificacao_fallback(Original, omitir(Original)).

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
% DISFARCE FORTE / IDENTIDADE SEGURA
% ============================================================

% Gera planos para fazer a identidade real se parecer com cada
% um dos outros suspeitos.
%
% O plano completo descreve como aproximar a aparência real da identidade
% imitada. Na hora da ação ele é recortado ou complementado para consumir
% exatamente o orçamento disponível.
preparar_planos_disfarce_forte(Suspeitos, IdReal) :-
    retractall(plano_disfarce_forte(_, _, _)),
    aparencia_suspeito(IdReal, Suspeitos, AparenciaReal),

    forall(
        (
            aparencia_suspeito(IdIsca, Suspeitos, AparenciaIsca),
            IdIsca \== IdReal,

            construir_plano_disfarce(
                AparenciaReal,
                AparenciaIsca,
                Plano
            ),

            Plano \= [],
            length(Plano, Custo),

            pontuacao_ambiguidade(
                AparenciaIsca,
                Suspeitos,
                AmbiguidadeIsca
            ),

            comprimento_prefixo_igual(
                AparenciaReal,
                AparenciaIsca,
                PrefixoIgual
            ),

            % A ambiguidade da identidade imitada tem maior peso.
            % Em caso de empate, favorece aparências que já possuem
            % um prefixo semelhante e exigem menos modificações.
            Pontuacao is
                AmbiguidadeIsca * 1000 +
                PrefixoIgual * 100 -
                Custo
        ),
        assertz(
            plano_disfarce_forte(
                Pontuacao,
                IdIsca,
                Plano
            )
        )
    ).


% Seleciona o plano de maior pontuação e o recorta ou complementa
% para consumir todos os pontos de disfarce disponíveis.
melhor_plano_disfarce_forte(
    PontosDisponiveis,
    AparenciaAtual,
    MelhorPlano,
    Quantidade
) :-
    PontosDisponiveis > 0,
    findall(
        Pontuacao-PlanoAjustado,
        (
            plano_disfarce_forte(
                Pontuacao,
                _IdIsca,
                PlanoCompleto
            ),
            ajustar_plano_ao_orcamento(
                PlanoCompleto,
                AparenciaAtual,
                PontosDisponiveis,
                PlanoAjustado
            ),
            length(PlanoAjustado, PontosDisponiveis)
        ),
        PlanosAplicaveis
    ),

    PlanosAplicaveis \= [],
    keysort(PlanosAplicaveis, PlanosOrdenados),
    last(PlanosOrdenados, _-MelhorPlano),
    length(MelhorPlano, Quantidade).

ajustar_plano_ao_orcamento(
    PlanoCompleto,
    _AparenciaAtual,
    PontosDisponiveis,
    Plano
) :-
    length(PlanoCompleto, Custo),
    Custo >= PontosDisponiveis,
    !,
    prefixo_tamanho(PlanoCompleto, PontosDisponiveis, Plano).
ajustar_plano_ao_orcamento(
    PlanoCompleto,
    AparenciaAtual,
    PontosDisponiveis,
    Plano
) :-
    length(PlanoCompleto, Custo),
    Faltam is PontosDisponiveis - Custo,
    atributos_reais(AparenciaAtual, Reais),
    exclude(
        atributo_ja_modificado(PlanoCompleto),
        Reais,
        Disponiveis
    ),
    maplist(modificacao_fallback, Disponiveis, Complementares),
    prefixo_tamanho(Complementares, Faltam, Complemento),
    append(PlanoCompleto, Complemento, Plano).

atributo_ja_modificado(Plano, Atributo) :-
    member(Modificacao, Plano),
    modificacao_altera(Modificacao, Atributo),
    !.

modificacao_altera(trocar(Atributo, _), Atributo).
modificacao_altera(omitir(Atributo), Atributo).

quantidade_limitada(Limite, Lista, Quantidade) :-
    length(Lista, Tamanho),
    Quantidade is min(Limite, Tamanho).

prefixo_tamanho(_Lista, 0, []) :-
    !.
prefixo_tamanho([Item | Itens], Quantidade, [Item | Prefixo]) :-
    Quantidade > 0,
    Restante is Quantidade - 1,
    prefixo_tamanho(Itens, Restante, Prefixo).


% Compara por functor, sem exigir que os atributos ocupem a mesma posição.
% Atributos reais sem equivalente são omitidos; atributos exclusivos da
% identidade-isca são adicionados.
construir_plano_disfarce(Reais, Iscas, Plano) :-
    maplist(modificacao_para_isca(Iscas), Reais, Mudancas0),
    exclude(==(none), Mudancas0, Mudancas),
    include(atributo_sem_tipo_em(Reais), Iscas, ExclusivosIsca),
    maplist(adicionar_atributo, ExclusivosIsca, Adicoes),
    append(Mudancas, Adicoes, Plano).

modificacao_para_isca(Iscas, Atributo, none) :-
    memberchk(Atributo, Iscas),
    !.
modificacao_para_isca(
    Iscas,
    AtributoReal,
    trocar(AtributoReal, AtributoIsca)
) :-
    member(AtributoIsca, Iscas),
    mesmo_tipo_atributo(AtributoReal, AtributoIsca),
    !.
modificacao_para_isca(_Iscas, AtributoReal, omitir(AtributoReal)).

atributo_sem_tipo_em(Atributos, Atributo) :-
    \+ memberchk(Atributo, Atributos),
    \+ (
        member(Existente, Atributos),
        mesmo_tipo_atributo(Existente, Atributo)
    ).

adicionar_atributo(Atributo, adicionar(Atributo)).


% Dois atributos são do mesmo tipo quando possuem o mesmo
% functor. Os valores podem ser diferentes.
mesmo_tipo_atributo(AtributoA, AtributoB) :-
    AtributoA =.. [Tipo, _],
    AtributoB =.. [Tipo, _].


% Conta quantos atributos idênticos existem consecutivamente
% no início das duas aparências.
comprimento_prefixo_igual(
    [Atributo | RestoA],
    [Atributo | RestoB],
    Quantidade
) :-
    !,
    comprimento_prefixo_igual(
        RestoA,
        RestoB,
        QuantidadeResto
    ),
    Quantidade is QuantidadeResto + 1.

comprimento_prefixo_igual(_, _, 0).


% Registra quantos pontos foram efetivamente gastos pelo plano.
% Também impede que o disfarce simples seja aplicado depois.
marcar_disfarce_feito(Quantidade) :-
    assertz(disfarce_forte_feito),

    retractall(disfarce_inicial_feito),
    assertz(disfarce_inicial_feito),

    retractall(disfarces_usados(_)),
    assertz(disfarces_usados(Quantidade)).

limpar_memoria_local :-
    retractall(plano_disfarce_forte(_, _, _)),
    retractall(disfarce_forte_feito).

% ============================================================
% MEMÓRIA
% ============================================================

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
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
