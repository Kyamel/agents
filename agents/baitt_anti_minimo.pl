:- module(baitt_anti_minimo, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- use_module(library(lists)).
:- use_module(library(random)).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.
:- dynamic tesouro_previsto/1.
:- dynamic tesouro_isca/1.
:- dynamic itens_isca/1.
:- dynamic itens_isca_roubados/1.
:- dynamic disfarce_inicial_feito/0.
:- dynamic disfarces_usados/1.
:- dynamic movimentos_feitos/1.
:- dynamic desvios_restantes/1.
:- dynamic cidade_anterior/1.

% ============================================================
% PARÂMETROS DA ESTRATÉGIA
% ============================================================

% O alvo real pode custar até este valor a mais que o tesouro mínimo.
folga_custo_alvo(3).

% Quantos itens exclusivos da cadeia falsa podem ser roubados.
% Um costuma ser suficiente para produzir uma primeira pista falsa.
limite_itens_isca(1).

% Máximo de passos extras aceitos para visitar um item-isca.
limite_custo_isca(3).

% Quantos desvios de exatamente um passo podem ser feitos na partida.
orcamento_desvios(3).

% Tenta um desvio a cada N decisões de movimento.
intervalo_desvio(3).

% O disfarce custa um turno. Para enfrentar especificamente um detetive
% de caminho mínimo, normalmente é melhor deixá-lo desligado.
usar_disfarce_inicial(false).

% ============================================================
% PRELOAD
% ============================================================

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

    escolher_identidade(Suspeitos, LadraoID),

    % O detetive guloso tende a prever o tesouro globalmente mais barato.
    % O ladrão escolhe uma alternativa quase tão barata e usa o mínimo
    % como isca explícita.
    escolher_tesouro_anti_minimo(ObjetivoLadrao, TesouroPrevisto),
    assertz(objetivo_atual(ObjetivoLadrao)),
    assertz(tesouro_previsto(TesouroPrevisto)),
    escolher_isca(ObjetivoLadrao, TesouroPrevisto),

    assertz(itens_isca_roubados(0)),
    assertz(disfarces_usados(0)),
    assertz(movimentos_feitos(0)),
    orcamento_desvios(Orcamento),
    assertz(desvios_restantes(Orcamento)).

% ============================================================
% AÇÕES
% ============================================================

ladrao_action(Contexto, Estado, Acao) :-
    once(decidir_acao(Contexto, Estado, Acao)).

% 1. Depois de obter o tesouro, evita retornar imediatamente e prefere
%    cidades com mais saídas, reduzindo a chance de ficar encurralado.
decidir_acao(_, thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    memberchk(Target, Itens),
    escolher_passo_fuga(Cidade, Proxima),
    registrar_movimento(Cidade, normal),
    !.

% 2. O tesouro real sempre tem prioridade quando já pode ser roubado.
decidir_acao(_, thief(loc(Cidade), _, _, Target, Itens, _),
             roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% 3. Rouba no máximo um item exclusivo da cadeia que o detetive guloso
%    provavelmente considera como alvo real.
decidir_acao(_, thief(loc(Cidade), _, _, Target, Itens, _),
             roubar(ItemIsca)) :-
    deve_usar_isca(Target, Itens),
    item_isca_disponivel_na_cidade(Cidade, Itens, ItemIsca),
    registrar_roubo_isca,
    !.

% 4. Se já está sobre qualquer folha disponível da cadeia real, rouba-a.
%    Não é obrigado a seguir a primeira exigência declarada na lista.
decidir_acao(_, thief(loc(Cidade), _, _, Target, Itens, _),
             roubar(Item)) :-
    escolher_item_real_na_cidade(Cidade, Target, Itens, Item),
    !.

% 5. Disfarce opcional. Fica desligado por padrão porque perde um turno.
decidir_acao(_, thief(loc(Cidade), _, aparencia(AS), Target, Itens, Dsg),
             disfarce([Modificacao])) :-
    usar_disfarce_inicial(true),
    Itens == [],
    \+ disfarce_inicial_feito,
    Dsg > 0,
    distancia_ate_proximo_real(Cidade, Target, Itens, Distancia),
    Distancia >= 4,
    escolher_disfarce_final(AS, Modificacao),
    Modificacao \= none,
    assertz(disfarce_inicial_feito),
    retractall(disfarces_usados(_)),
    assertz(disfarces_usados(1)),
    !.

% 6. Antes da primeira pista real, aceita um pequeno desvio para roubar
%    um item da cadeia prevista pelo detetive.
decidir_acao(_, thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    deve_usar_isca(Target, Itens),
    escolher_item_isca_viavel(Cidade, Target, Itens,
                              _ItemIsca, CidadeIsca),
    passo_curto_variavel(Cidade, CidadeIsca, Proxima),
    registrar_movimento(Cidade, normal),
    !.

% 7. Segue a cadeia real, mas escolhe entre folhas disponíveis em vez de
%    obedecer à ordem da lista. A rota pode conter desvios controlados.
decidir_acao(_, thief(loc(Cidade), _, _, Target, Itens, _),
             move(Cidade, Proxima)) :-
    escolher_proximo_real(Cidade, Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    passo_anti_minimo(Cidade, CidadeObjetivo, Itens, Proxima, Tipo),
    registrar_movimento(Cidade, Tipo),
    !.

decidir_acao(_, _, nada).

% ============================================================
% ESCOLHA DO ALVO: NÃO CONFIRMAR O MODELO GULOSO
% ============================================================

escolher_tesouro_anti_minimo(Target, Previsto) :-
    findall(Custo-T,
        custo_tesouro(T, Custo),
        Pares),
    keysort(Pares, Ordenados),
    Ordenados = [CustoMin-Previsto | Alternativas],
    folga_custo_alvo(Folga),
    Limite is CustoMin + Folga,
    candidatos_ate_limite(Alternativas, Limite, Proximos),
    primeiros_n(3, Proximos, Candidatos),
    escolher_alvo_candidato(Candidatos, Previsto, Target).

escolher_alvo_candidato([], Previsto, Previsto) :- !.
escolher_alvo_candidato(Candidatos, _, Target) :-
    random_member(_-Target, Candidatos).

candidatos_ate_limite([], _, []).
candidatos_ate_limite([C-T | Resto], Limite, [C-T | Filtrados]) :-
    C =< Limite,
    !,
    candidatos_ate_limite(Resto, Limite, Filtrados).
candidatos_ate_limite([_ | Resto], Limite, Filtrados) :-
    candidatos_ate_limite(Resto, Limite, Filtrados).

primeiros_n(N, Lista, Primeiros) :-
    N > 0,
    primeiros_n_(Lista, N, Primeiros).

primeiros_n_(_, 0, []) :- !.
primeiros_n_([], _, []).
primeiros_n_([X | Xs], N, [X | Ys]) :-
    N1 is N - 1,
    primeiros_n_(Xs, N1, Ys).

custo_tesouro(Tesouro, Custo) :-
    cadeia_itens_tesouro(Tesouro, Itens),
    length(Itens, NumeroItens),
    tesouro_conhecido(Tesouro, _, Requisitos),
    length(Requisitos, RequisitosDiretos),
    Custo is NumeroItens + RequisitosDiretos.

% ============================================================
% ISCA
% ============================================================

escolher_isca(Target, Previsto) :-
    Previsto \= Target,
    itens_exclusivos(Previsto, Target, Exclusivos),
    Exclusivos \= [],
    !,
    assertz(tesouro_isca(Previsto)),
    assertz(itens_isca(Exclusivos)).
escolher_isca(Target, _) :-
    melhor_isca_alternativa(Target, Isca, Exclusivos),
    !,
    assertz(tesouro_isca(Isca)),
    assertz(itens_isca(Exclusivos)).
escolher_isca(_, _) :-
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])).

melhor_isca_alternativa(Target, Isca, Exclusivos) :-
    findall(Custo-(T-ExclusivosT),
        ( tesouro_conhecido(T, _, _),
          T \= Target,
          itens_exclusivos(T, Target, ExclusivosT),
          ExclusivosT \= [],
          custo_tesouro(T, Custo)
        ),
        Opcoes),
    keysort(Opcoes, [_-(Isca-Exclusivos) | _]).

itens_exclusivos(Isca, Target, Exclusivos) :-
    cadeia_itens_tesouro(Isca, ItensIsca),
    cadeia_itens_tesouro(Target, ItensTarget),
    subtract(ItensIsca, ItensTarget, Exclusivos0),
    sort(Exclusivos0, Exclusivos).

deve_usar_isca(Target, Itens) :-
    tesouro_isca(Isca),
    Isca \= nenhum,
    itens_isca_roubados(Quantidade),
    limite_itens_isca(Limite),
    Quantidade < Limite,
    \+ possui_item_da_cadeia(Target, Itens).

possui_item_da_cadeia(Target, Itens) :-
    cadeia_itens_tesouro(Target, Cadeia),
    member(Item, Cadeia),
    memberchk(Item, Itens),
    !.

item_isca_disponivel_na_cidade(Cidade, Itens, Item) :-
    itens_isca(ItensIsca),
    findall(Ambiguidade-I,
        ( member(I, ItensIsca),
          \+ memberchk(I, Itens),
          item_conhecido(I, Cidade, Requisitos),
          requisitos_satisfeitos(Requisitos, Itens),
          ambiguidade_item(I, Ambiguidade)
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_-Item | _]).

escolher_item_isca_viavel(Cidade, Target, Itens, ItemIsca, CidadeIsca) :-
    escolher_proximo_real(Cidade, Target, Itens, ObjetoReal),
    cidade_do_objeto(ObjetoReal, CidadeReal),
    distancia_bfs(Cidade, CidadeReal, Direto),
    limite_custo_isca(Limite),
    itens_isca(ItensIsca),
    findall(Extra-(D1-(I-CI)),
        ( member(I, ItensIsca),
          \+ memberchk(I, Itens),
          item_conhecido(I, CI, Requisitos),
          requisitos_satisfeitos(Requisitos, Itens),
          distancia_bfs(Cidade, CI, D1),
          distancia_bfs(CI, CidadeReal, D2),
          Extra is D1 + D2 - Direto,
          Extra =< Limite
        ),
        Opcoes),
    Opcoes \= [],
    keysort(Opcoes, [_-(_-(ItemIsca-CidadeIsca)) | _]).

registrar_roubo_isca :-
    retract(itens_isca_roubados(N)),
    N1 is N + 1,
    assertz(itens_isca_roubados(N1)).

% ============================================================
% ESCOLHA DOS ITENS REAIS
% ============================================================

% Uma folha disponível é qualquer item da cadeia real ainda não roubado
% cujos próprios requisitos já estão satisfeitos. Isso permite executar
% uma ordem topológica diferente daquela prevista pelo detetive.
item_real_disponivel(Target, Itens, Item, Cidade) :-
    item_da_cadeia(Target, Item),
    \+ memberchk(Item, Itens),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).

escolher_item_real_na_cidade(Cidade, Target, Itens, Item) :-
    findall(Ambiguidade-I,
        ( item_real_disponivel(Target, Itens, I, Cidade),
          ambiguidade_item(I, Ambiguidade)
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_-Item | _]).

escolher_proximo_real(Cidade, Target, Itens, Target) :-
    tesouro_conhecido(Target, _, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
escolher_proximo_real(Cidade, Target, Itens, ItemEscolhido) :-
    findall(Distancia-I,
        ( item_real_disponivel(Target, Itens, I, CidadeItem),
          distancia_bfs(Cidade, CidadeItem, Distancia)
        ),
        Pares),
    keysort(Pares, Ordenados),
    escolher_item_anti_guloso(Ordenados, ItemEscolhido).

% Não escolhe automaticamente o item disponível mais próximo. Se houver
% outra opção até dois passos mais cara, prefere a mais ambígua entre elas.
escolher_item_anti_guloso([DistMin-Primeiro | Resto], Escolhido) :-
    Limite is DistMin + 2,
    candidatos_ate_limite(Resto, Limite, Alternativos),
    Alternativos \= [],
    !,
    escolher_mais_ambiguo(Alternativos, Escolhido).
escolher_item_anti_guloso([_-Item | _], Item).

escolher_mais_ambiguo(Candidatos, Item) :-
    findall(Ambiguidade-(D-I),
        ( member(D-I, Candidatos),
          ambiguidade_item(I, Ambiguidade)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_-(_-Item) | _]).

ambiguidade_item(Item, Quantidade) :-
    findall(T,
        ( tesouro_conhecido(T, _, _),
          item_da_cadeia(T, Item)
        ),
        Tesouros),
    sort(Tesouros, Unicos),
    length(Unicos, Quantidade).

distancia_ate_proximo_real(Cidade, Target, Itens, Distancia) :-
    escolher_proximo_real(Cidade, Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    distancia_bfs(Cidade, CidadeObjetivo, Distancia).

% ============================================================
% ROTAS ANTI-CAMINHO-MÍNIMO
% ============================================================

passo_anti_minimo(Origem, Destino, Itens, Proxima, desvio) :-
    deve_tentar_desvio(Origem, Destino),
    cidade_prevista_detetive(Itens, CidadePrevista),
    CidadePrevista \= Destino,
    escolher_passo_desvio(Origem, Destino, CidadePrevista, Proxima),
    !.
passo_anti_minimo(Origem, Destino, _, Proxima, desvio) :-
    deve_tentar_desvio(Origem, Destino),
    escolher_passo_lateral(Origem, Destino, Proxima),
    !.
passo_anti_minimo(Origem, Destino, _, Proxima, normal) :-
    passo_curto_variavel(Origem, Destino, Proxima).

deve_tentar_desvio(Origem, Destino) :-
    desvios_restantes(Restantes),
    Restantes > 0,
    movimentos_feitos(Movimentos),
    intervalo_desvio(Intervalo),
    0 is Movimentos mod Intervalo,
    distancia_bfs(Origem, Destino, Distancia),
    Distancia > 2.

% Escolhe um vizinho que adiciona exatamente um passo à rota real e, ao
% mesmo tempo, aproxima o ladrão do objetivo que o detetive prevê.
escolher_passo_desvio(Origem, Destino, CidadePrevista, Proxima) :-
    vizinhos_unicos(Origem, Vizinhos),
    menor_distancia_vizinhos(Vizinhos, Destino, Melhor),
    distancia_bfs(Origem, CidadePrevista, PrevistaAtual),
    findall(Ganho-V,
        ( member(V, Vizinhos),
          nao_eh_retorno_imediato(V),
          distancia_bfs(V, Destino, DReal),
          DReal =:= Melhor + 1,
          distancia_bfs(V, CidadePrevista, DPrevista),
          DPrevista < PrevistaAtual,
          Ganho is PrevistaAtual - DPrevista
        ),
        Candidatos),
    Candidatos \= [],
    keysort(Candidatos, Ordenados),
    reverse(Ordenados, [MelhorGanho-_ | _]),
    findall(V,
        member(MelhorGanho-V, Candidatos),
        Empatados),
    random_member(Proxima, Empatados).

% Fallback: faz um passo lateral de custo +1 mesmo que ele não aponte
% diretamente para a isca. Ainda quebra a previsão exata da rota mínima.
escolher_passo_lateral(Origem, Destino, Proxima) :-
    vizinhos_unicos(Origem, Vizinhos),
    menor_distancia_vizinhos(Vizinhos, Destino, Melhor),
    findall(Grau-V,
        ( member(V, Vizinhos),
          nao_eh_retorno_imediato(V),
          distancia_bfs(V, Destino, DReal),
          DReal =:= Melhor + 1,
          grau_cidade(V, Grau)
        ),
        Candidatos),
    Candidatos \= [],
    keysort(Candidatos, Ordenados),
    reverse(Ordenados, [MelhorGrau-_ | _]),
    findall(V,
        member(MelhorGrau-V, Candidatos),
        Empatados),
    random_member(Proxima, Empatados).

% Quando segue uma rota mínima, randomiza entre todos os primeiros passos
% mínimos. Isso evita que a ordem das arestas determine sempre a mesma rota.
passo_curto_variavel(Origem, Destino, Proxima) :-
    Origem \= Destino,
    vizinhos_unicos(Origem, Vizinhos),
    menor_distancia_vizinhos(Vizinhos, Destino, Melhor),
    findall(V,
        ( member(V, Vizinhos),
          distancia_bfs(V, Destino, Melhor)
        ),
        Minimos0),
    remover_retorno_se_possivel(Minimos0, Minimos),
    random_member(Proxima, Minimos).

menor_distancia_vizinhos([V | Vs], Destino, Melhor) :-
    distancia_bfs(V, Destino, Inicial),
    menor_distancia_vizinhos_(Vs, Destino, Inicial, Melhor).

menor_distancia_vizinhos_([], _, Melhor, Melhor).
menor_distancia_vizinhos_([V | Vs], Destino, Atual, Melhor) :-
    distancia_bfs(V, Destino, D),
    Novo is min(Atual, D),
    menor_distancia_vizinhos_(Vs, Destino, Novo, Melhor).

cidade_prevista_detetive(Itens, Cidade) :-
    tesouro_previsto(TargetPrevisto),
    proximo_objetivo_guloso(TargetPrevisto, Itens, Objeto),
    cidade_do_objeto(Objeto, Cidade).

% Modelo simplificado do detetive adversário: primeiro requisito pendente
% e resolução recursiva sempre pela primeira posição da lista.
proximo_objetivo_guloso(Target, Itens, Proximo) :-
    tesouro_conhecido(Target, _, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito_guloso(Req, Itens, Proximo).
proximo_objetivo_guloso(Target, _, Target).

resolver_requisito_guloso(Item, Itens, Proximo) :-
    item_conhecido(Item, _, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito_guloso(Req, Itens, Proximo).
resolver_requisito_guloso(Item, _, Item).

registrar_movimento(Cidade, Tipo) :-
    retract(movimentos_feitos(N)),
    N1 is N + 1,
    assertz(movimentos_feitos(N1)),
    retractall(cidade_anterior(_)),
    assertz(cidade_anterior(Cidade)),
    consumir_desvio(Tipo).

consumir_desvio(desvio) :-
    retract(desvios_restantes(N)),
    N1 is max(0, N - 1),
    assertz(desvios_restantes(N1)),
    !.
consumir_desvio(_).

nao_eh_retorno_imediato(Cidade) :-
    ( cidade_anterior(Anterior) -> Cidade \= Anterior ; true ).

remover_retorno_se_possivel(Candidatos, Filtrados) :-
    cidade_anterior(Anterior),
    delete(Candidatos, Anterior, SemAnterior),
    SemAnterior \= [],
    !,
    Filtrados = SemAnterior.
remover_retorno_se_possivel(Candidatos, Candidatos).

% ============================================================
% FUGA
% ============================================================

escolher_passo_fuga(Cidade, Proxima) :-
    vizinhos_unicos(Cidade, Vizinhos0),
    remover_retorno_se_possivel(Vizinhos0, Vizinhos),
    findall(Grau-V,
        ( member(V, Vizinhos),
          grau_cidade(V, Grau)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [MelhorGrau-_ | _]),
    findall(V,
        member(MelhorGrau-V, Pares),
        Empatados),
    random_member(Proxima, Empatados).

grau_cidade(Cidade, Grau) :-
    vizinhos_unicos(Cidade, Vizinhos),
    length(Vizinhos, Grau).

vizinhos_unicos(Cidade, Vizinhos) :-
    findall(V, aresta_conhecida(Cidade, V), ComRepeticao),
    sort(ComRepeticao, Vizinhos),
    Vizinhos \= [].

% ============================================================
% REQUISITOS E CADEIAS
% ============================================================

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    memberchk(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

requisito_pendente([Req | _], Itens, Req) :-
    \+ memberchk(Req, Itens),
    !.
requisito_pendente([_ | Resto], Itens, Pendente) :-
    requisito_pendente(Resto, Itens, Pendente).

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

cidade_do_objeto(Objeto, Cidade) :-
    item_conhecido(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_conhecido(Objeto, Cidade, _).

% ============================================================
% DISFARCE E IDENTIDADE
% ============================================================

escolher_disfarce_final(AS, trocar(Original, Falso)) :-
    findall(A, (member(A, AS), A \= disfarce(_, _)), Reais),
    Reais \= [],
    last(Reais, Original),
    Original =.. [Functor, ValorAtual],
    valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso),
    Falso =.. [Functor, ValorFalso],
    !.
escolher_disfarce_final(AS, omitir(Original)) :-
    findall(A, (member(A, AS), A \= disfarce(_, _)), Reais),
    Reais \= [],
    last(Reais, Original),
    !.

valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso) :-
    suspeito_conhecido(procurado(_, _, aparencia(Atributos))),
    member(Atributo, Atributos),
    Atributo =.. [Functor, ValorFalso],
    ValorFalso \= ValorAtual,
    !.
valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso) :-
    suspeito_conhecido(procurado(_, aparencia(Atributos))),
    member(Atributo, Atributos),
    Atributo =.. [Functor, ValorFalso],
    ValorFalso \= ValorAtual,
    !.

escolher_identidade(Suspeitos, LadraoID) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_-LadraoID | _]).

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _, aparencia(Aparencia)), Suspeitos),
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
    append(Prefixo, _, Lista).

prefixo_compativel([], _).
prefixo_compativel([A | As], [A | Bs]) :-
    prefixo_compativel(As, Bs).

% ============================================================
% MEMÓRIA
% ============================================================

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)),
    retractall(tesouro_previsto(_)),
    retractall(tesouro_isca(_)),
    retractall(itens_isca(_)),
    retractall(itens_isca_roubados(_)),
    retractall(disfarce_inicial_feito),
    retractall(disfarces_usados(_)),
    retractall(movimentos_feitos(_)),
    retractall(desvios_restantes(_)),
    retractall(cidade_anterior(_)).

lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).

% ============================================================
% BFS
% ============================================================

distancia_bfs(Origem, Destino, 0) :-
    Origem == Destino,
    !.
distancia_bfs(Origem, Destino, Distancia) :-
    bfs_dist([[Origem, 0]], [Origem], Destino, Distancia).

bfs_dist([[Destino, D] | _], _, Destino, D) :- !.
bfs_dist([[Atual, D] | Fila], Visitados, Destino, Distancia) :-
    D1 is D + 1,
    findall(Vizinho,
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, Visitados)
        ),
        Novos0),
    sort(Novos0, Novos),
    findall([Vizinho, D1], member(Vizinho, Novos), Entradas),
    append(Visitados, Novos, VisitadosAtualizados),
    append(Fila, Entradas, FilaAtualizada),
    bfs_dist(FilaAtualizada, VisitadosAtualizados,
             Destino, Distancia).