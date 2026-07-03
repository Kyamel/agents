% ============================================================
% Nome: Mayker Anselmo Brito Lellis     Matricula: 22.2.8008
% Nome: Lucas dos Anjos Camelo          Matricula: 22.2.8002
% ============================================================

% ============================================================
% AGENTE LADRAO: ladrao_raffles
%
% Estrategias empregadas:
%
% 1. TESOURO: escolhe uma das menores cadeias de pre-requisitos
%    recursivos, reduzindo o numero de roubos necessarios.
%
% 2. IDENTIDADE: escolhe um suspeito cujas primeiras pistas
%    mantenham o maior numero de identidades compativeis.
%
% 3. DISFARCE FORTE: compara a identidade real com todos os
%    outros suspeitos e gera planos para imitar suas primeiras
%    caracteristicas. O plano escolhido deve caber nos pontos de
%    disfarce disponiveis e dificultar um mandato correto.
%
% 4. DISFARCE SIMPLES: quando nenhum plano forte pode ser usado,
%    altera uma das primeiras caracteristicas, priorizando a
%    modificacao que mais confunde as primeiras pistas.
%
% 5. BAIT STRATEGY: coleta no maximo um item de uma cadeia
%    secundaria quando o desvio espacial e pequeno.
%
% 6. DIVERSIFICACAO DE OBJETIVO: quando existem folhas pendentes
%    independentes, pode visitar uma folha diferente daquela
%    escolhida pela ordem canonica dos requisitos.
%
% 7. ROTA EVASIVA: depois de cada roubo, tenta construir uma rota
%    curta que evita o inicio do caminho minimo previsivel.
%
% 8. FUGA IMPREVISIVEL: depois de roubar o tesouro, evita a saida
%    canonica e o retorno imediato, randomizando entre alternativas.
%
% 9. COBERTURA DE OBJETIVO: prepara tambem a cadeia de um segundo
%    tesouro. Assim, observar os roubos nao identifica de forma unica
%    qual cidade final deve ser bloqueada.
%
% ============================================================

:- module(ladrao_raffles, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.

:- dynamic tesouro_isca/1.
:- dynamic itens_isca/1.
:- dynamic bait_usado/0.
:- dynamic tesouro_cobertura/1.
:- dynamic cidade_cobertura_perigosa/1.
:- dynamic fila_bloqueios_prevista/1.
:- dynamic bloqueio_persistente_previsto/1.
:- dynamic cidade_ja_bloqueada_prevista/1.
:- dynamic armadilha_gulosa_prevista/1.
:- dynamic origem_roubo_recente/1.

:- dynamic plano_disfarce_forte/3.
:- dynamic disfarce_forte_feito/0.
:- dynamic disfarce_inicial_feito/0.

:- dynamic cidade_anterior/1.
:- dynamic total_itens_observado/1.
:- dynamic rota_evasiva/1.
:- dynamic destino_rota_evasiva/1.
:- dynamic rota_bfs_prevista/1.
:- dynamic escolha_diversificada/3.

% Quantos passos extras uma rota evasiva pode custar.
folga_maxima_desvio(3).

% Quantos vertices iniciais do caminho previsto tentamos evitar.
prefixo_perigoso_maximo(3).

% Quantas primeiras pistas recebem maior peso na avaliacao.
limite_pistas_avaliadas(5).

% ============================================================
% PRELOAD
% ============================================================

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
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
    configurar_tesouro_cobertura(ObjetivoLadrao, Grafo),
    preparar_planos_disfarce_forte(Suspeitos, LadraoID),
    configurar_bait_strategy(ObjetivoLadrao),

    assertz(total_itens_observado(0)),
    assertz(rota_evasiva([])),
    assertz(destino_rota_evasiva(nenhum)),
    assertz(rota_bfs_prevista([])),
    assertz(fila_bloqueios_prevista([])),
    inicializar_armadilha_gulosa.

% ============================================================
% ACAO PRINCIPAL
% ============================================================

ladrao_action(Eventos, Estado, AcaoFinal) :-
    preparar_turno(Estado),
    acao_base(Eventos, Estado, AcaoInicial),
    ajustar_acao_cadeia(Estado, AcaoInicial, AcaoAjustada),
    adaptar_movimento(Estado, AcaoAjustada, AcaoFinal),
    avancar_modelo_bloqueios,
    !.
ladrao_action(_, _, nada).

% ============================================================
% MEMORIA DE ROUBOS E PLANEJAMENTO EVASIVO
% ============================================================

% O inventario aumenta depois de cada roubo. No turno seguinte,
% o agente usa essa mudanca para planejar uma rota diferente do
% caminho minimo que um detetive previsivel pode antecipar.
preparar_turno(thief(loc(Cidade), _, _, Target, Itens, _)) :-
    length(Itens, TotalAtual),
    total_itens_observado(TotalAnterior),
    (   TotalAtual > TotalAnterior
    ->  retractall(total_itens_observado(_)),
        assertz(total_itens_observado(TotalAtual)),
        atualizar_cidade_cobertura_perigosa(Itens),
        atualizar_modelo_bloqueios(Cidade, Itens),
        planejar_apos_roubo(Cidade, Target, Itens)
    ;   true
    ),
    !.
preparar_turno(_).

planejar_apos_roubo(_, Target, Itens) :-
    memberchk(Target, Itens),
    !,
    limpar_rota_evasiva.
planejar_apos_roubo(Cidade, Target, Itens) :-
    destino_estrategico(Cidade, Target, Itens, Destino),
    Cidade \== Destino,
    !,
    planejar_rota_anti_bfs(Cidade, Destino).
planejar_apos_roubo(_, _, _) :-
    limpar_rota_evasiva.

% ============================================================
% BASE DE DECISAO
% ============================================================

% Aplica o melhor plano de duas ou mais modificacoes antes do
% primeiro roubo. O plano precisa caber nos pontos restantes.
acao_base(_, thief(_, _, _, _, Itens, Dsg),
          disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_forte_feito,
    melhor_plano_disfarce_forte(Dsg, Modificacoes, Quantidade),
    Quantidade >= 2,
    marcar_disfarce_forte,
    !.

% Quando o tesouro ja foi obtido, basta sair de sua cidade.
% adaptar_movimento/3 substitui esta primeira aresta por uma
% saida menos previsivel quando houver alternativa.
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _),
          move(Cidade, Vizinho)) :-
    memberchk(Target, Itens),
    aresta_conhecida(Cidade, Vizinho),
    !.

% Fallback de um unico disfarce. Diferentemente da versao antiga,
% avalia as primeiras caracteristicas, que sao reveladas primeiro.
acao_base(_, thief(_, Id, aparencia(Aparencia), _, Itens, Dsg),
          disfarce([Modificacao])) :-
    Itens == [],
    \+ disfarce_inicial_feito,
    Dsg > 0,
    escolher_disfarce_inicial(Id, Aparencia, Modificacao),
    assertz(disfarce_inicial_feito),
    !.

% Rouba o tesouro real assim que todos os requisitos estiverem
% satisfeitos e o ladrao estiver na cidade correta.
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _),
          roubar(Target)) :-
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% A bait strategy pode produzir apenas um roubo secundario por
% partida, evitando entregar pistas demais ao detetive.
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _),
          roubar(ItemIsca)) :-
    \+ bait_usado,
    item_isca_disponivel(Cidade, Target, Itens, ItemIsca),
    assertz(bait_usado),
    !.

% Move para o unico item de isca permitido quando o desvio total
% em relacao a cadeia real e pequeno.
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _),
          move(Cidade, ProximaCidade)) :-
    \+ bait_usado,
    cidade_isca_ativa(Cidade, Target, Itens, CidadeIsca),
    proximo_passo(Cidade, CidadeIsca, ProximaCidade),
    !.

% Rouba a proxima folha da cadeia real.
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _),
          roubar(Item)) :-
    proximo_objetivo(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% Segue para o proximo item ou para o tesouro.
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _),
          move(Cidade, ProximaCidade)) :-
    proximo_objetivo(Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo(Cidade, CidadeObjetivo, ProximaCidade),
    !.

acao_base(_, _, nada).

% ============================================================
% DIVERSIFICACAO DA CADEIA REAL
% ============================================================

% A decisao base segue a primeira dependencia pendente. Este
% pos-processamento pode trocar o objetivo por outra folha pronta
% e nao mais distante, quebrando a previsao baseada na ordem da lista.
ajustar_acao_cadeia(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, PassoCanonico),
    Acao
) :-
    modo_cadeia_real(Cidade, Target, Itens),
    !,
    acao_cadeia_real(Cidade, Target, Itens, PassoCanonico, Acao).
ajustar_acao_cadeia(_, Acao, Acao).

modo_cadeia_real(Cidade, Target, Itens) :-
    \+ memberchk(Target, Itens),
    \+ cidade_isca_ativa(Cidade, Target, Itens, _).

% Se o desvio anterior levou a uma folha pronta, rouba-a.
acao_cadeia_real(Cidade, Target, Itens, _, roubar(Item)) :-
    objetivo_pendente(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% Caso exista outra folha pendente tao perto quanto a canonica,
% segue para essa folha alternativa.
acao_cadeia_real(Cidade, Target, Itens, _,
                 move(Cidade, Passo)) :-
    destino_diversificado(Cidade, Target, Itens, CidadeDiversificada),
    proximo_passo(Cidade, CidadeDiversificada, Passo),
    !.

acao_cadeia_real(Cidade, _, _, PassoCanonico,
                 move(Cidade, PassoCanonico)).

% Escolhe uma folha alternativa com distancia nao superior a da
% folha canonica. A escolha e randomizada uma vez por estado do
% inventario e depois mantida estavel ate o proximo roubo.
destino_diversificado(Cidade, Target, Itens, CidadeDiversificada) :-
    sort(Itens, ChaveItens),
    escolha_diversificada(Target, ChaveItens, CidadeDiversificada),
    objetivo_pendente(Target, Itens, ObjetoEscolhido),
    cidade_do_objeto(ObjetoEscolhido, CidadeDiversificada),
    CidadeDiversificada \== Cidade,
    !.
destino_diversificado(Cidade, Target, Itens, CidadeDiversificada) :-
    proximo_objetivo(Target, Itens, ObjetoCanonico),
    cidade_do_objeto(ObjetoCanonico, CidadeCanonica),
    distancia_bfs(Cidade, CidadeCanonica, DistanciaCanonica),

    findall(Distancia-CidadeAlternativa,
        ( objetivo_pendente(Target, Itens, ObjetoAlternativo),
          ObjetoAlternativo \== ObjetoCanonico,
          cidade_do_objeto(ObjetoAlternativo, CidadeAlternativa),
          CidadeAlternativa \== CidadeCanonica,
          distancia_bfs(Cidade, CidadeAlternativa, Distancia),
          Distancia =< DistanciaCanonica
        ),
        Pares),

    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [MenorDistancia-_ | _],
    findall(C,
            member(MenorDistancia-C, Ordenados),
            MelhoresCidades0),
    sort(MelhoresCidades0, MelhoresCidades),
    random_member(CidadeDiversificada, MelhoresCidades),
    sort(Itens, ChaveItens),
    retractall(escolha_diversificada(_, _, _)),
    assertz(escolha_diversificada(
        Target,
        ChaveItens,
        CidadeDiversificada
    )).

objetivo_pendente(Target, Itens, Folha) :-
    tesouro_planejado(Target, Itens, Planejado),
    tesouro_conhecido(Planejado, _, Requisitos),
    member(Requisito, Requisitos),
    Requisito \== Planejado,
    \+ memberchk(Requisito, Itens),
    resolver_requisito(Requisito, Itens, Folha).

% ============================================================
% ADAPTACAO DOS MOVIMENTOS
% ============================================================

% Depois do tesouro, evita a saida canonica e o retorno imediato.
adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, PassoCanonico),
    move(Cidade, Proxima)
) :-
    memberchk(Target, Itens),
    !,
    escolher_saida_imprevisivel(Cidade, PassoCanonico, Proxima),
    registrar_saida(Cidade).

% Nos demais deslocamentos, usa primeiro uma rota evasiva planejada;
% na ausencia dela, randomiza entre caminhos minimos equivalentes.
adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, PassoCanonico),
    move(Cidade, Proxima)
) :-
    destino_estrategico(Cidade, Target, Itens, Destino),
    !,
    escolher_passo_para_destino(
        Cidade,
        Destino,
        PassoCanonico,
        Proxima
    ),
    registrar_saida(Cidade).

% Fallback para movimentos cujo destino final nao pode ser inferido.
adaptar_movimento(
    thief(loc(Cidade), _, _, _, _, _),
    move(Cidade, PassoCanonico),
    move(Cidade, Proxima)
) :-
    !,
    escolher_saida_imprevisivel(Cidade, PassoCanonico, Proxima),
    registrar_saida(Cidade).

adaptar_movimento(_, Acao, Acao).

% Determina o objetivo espacial atual usando a mesma prioridade da
% base de decisao: isca, folha diversificada e objetivo canonico.
destino_estrategico(Cidade, Target, Itens, Destino) :-
    \+ memberchk(Target, Itens),
    (   cidade_isca_ativa(Cidade, Target, Itens, Destino)
    ->  true
    ;   destino_diversificado(Cidade, Target, Itens, Destino)
    ->  true
    ;   proximo_objetivo(Target, Itens, Objeto),
        cidade_do_objeto(Objeto, Destino)
    ).

escolher_passo_para_destino(Cidade, Destino, _, Proxima) :-
    passo_evitando_riscos(Cidade, Destino, Proxima),
    !.
escolher_passo_para_destino(Cidade, Destino, _, Proxima) :-
    consumir_passo_rota(Cidade, Destino, Proxima),
    !.
escolher_passo_para_destino(Cidade, Destino, PassoCanonico, Proxima) :-
    passo_minimo_alternativo(
        Cidade,
        Destino,
        PassoCanonico,
        Proxima
    ),
    !.
escolher_passo_para_destino(_, _, PassoCanonico, PassoCanonico).

passo_evitando_riscos(Cidade, Destino, Proxima) :-
    findall(Perigosa,
            cidade_a_evitar(Perigosa),
            Perigos0),
    sort(Perigos0, Perigos),
    Perigos \= [],
    delete(Perigos, Cidade, Bloqueados),
    \+ memberchk(Destino, Bloqueados),
    caminho_evasivo(Cidade, Destino, Bloqueados,
                    [Cidade, Proxima | _]).

cidade_a_evitar(Cidade) :-
    cidade_cobertura_perigosa(Cidade).
cidade_a_evitar(Cidade) :-
    proximo_bloqueio_previsto(Cidade).
cidade_a_evitar(Cidade) :-
    armadilha_gulosa_prevista(Cidade).
cidade_a_evitar(Cidade) :-
    origem_roubo_recente(Cidade).

% ============================================================
% ROTA ANTI-CAMINHO-MINIMO
% ============================================================

% Calcula o caminho BFS previsivel e procura uma rota curta que
% nao atravesse os primeiros vertices internos desse caminho.
planejar_rota_anti_bfs(Origem, Destino) :-
    Origem \== Destino,
    caminho_mais_curto(Origem, Destino, RotaPrevista),
    RotaPrevista = [Origem | Cauda],
    internos_da_rota(Cauda, Destino, Internos),

    retractall(rota_bfs_prevista(_)),
    assertz(rota_bfs_prevista(RotaPrevista)),

    (   encontrar_desvio_controlado(
            Origem,
            Destino,
            RotaPrevista,
            Internos,
            RotaAlternativa
        )
    ->  salvar_rota_evasiva(Destino, RotaAlternativa)
    ;   limpar_rota_evasiva
    ),
    !.
planejar_rota_anti_bfs(_, _) :-
    limpar_rota_evasiva.

% Tenta primeiro bloquear um prefixo maior da rota prevista e
% reduz esse conjunto se o desvio ficar caro ou impossivel.
encontrar_desvio_controlado(
    Origem,
    Destino,
    RotaPrevista,
    Internos,
    RotaAlternativa
) :-
    distancia_da_rota(RotaPrevista, DistanciaMinima),
    folga_maxima_desvio(FolgaMaxima),
    prefixo_perigoso_maximo(Maximo),

    (   primeiros_n(Maximo, Internos, BloqueadosMax),
        BloqueadosMax \= [],
        tentar_rota_bloqueando(
            Origem,
            Destino,
            BloqueadosMax,
            DistanciaMinima,
            FolgaMaxima,
            RotaAlternativa
        )
    ;   primeiros_n(2, Internos, Bloqueados2),
        Bloqueados2 \= [],
        tentar_rota_bloqueando(
            Origem,
            Destino,
            Bloqueados2,
            DistanciaMinima,
            2,
            RotaAlternativa
        )
    ;   primeiros_n(1, Internos, Bloqueados1),
        Bloqueados1 \= [],
        tentar_rota_bloqueando(
            Origem,
            Destino,
            Bloqueados1,
            DistanciaMinima,
            1,
            RotaAlternativa
        )
    ),

    RotaAlternativa \= RotaPrevista,
    !.

 tentar_rota_bloqueando(
    Origem,
    Destino,
    Bloqueados,
    DistanciaMinima,
    Folga,
    Rota
) :-
    caminho_evasivo(Origem, Destino, Bloqueados, Rota),
    distancia_da_rota(Rota, DistanciaAlternativa),
    Limite is DistanciaMinima + Folga,
    DistanciaAlternativa =< Limite.

internos_da_rota(Cauda, Destino, Internos) :-
    append(Internos, [Destino], Cauda),
    !.
internos_da_rota(_, _, []).

distancia_da_rota(Rota, Distancia) :-
    length(Rota, QuantidadeVertices),
    Distancia is max(0, QuantidadeVertices - 1).

salvar_rota_evasiva(Destino, [_Origem | Passos]) :-
    Passos \= [],
    retractall(rota_evasiva(_)),
    assertz(rota_evasiva(Passos)),
    retractall(destino_rota_evasiva(_)),
    assertz(destino_rota_evasiva(Destino)).

limpar_rota_evasiva :-
    retractall(rota_evasiva(_)),
    assertz(rota_evasiva([])),
    retractall(destino_rota_evasiva(_)),
    assertz(destino_rota_evasiva(nenhum)).

consumir_passo_rota(Cidade, Destino, Proxima) :-
    destino_rota_evasiva(Destino),
    rota_evasiva([Proxima | Resto]),
    aresta_conhecida(Cidade, Proxima),
    retractall(rota_evasiva(_)),
    assertz(rota_evasiva(Resto)),
    !.

% BFS que ignora vertices bloqueados e embaralha vizinhos para
% nao escolher sempre a mesma rota alternativa.
caminho_evasivo(Origem, Destino, Bloqueados, Caminho) :-
    \+ memberchk(Origem, Bloqueados),
    \+ memberchk(Destino, Bloqueados),
    bfs_evasivo(
        [[Origem]],
        [Origem],
        Destino,
        Bloqueados,
        CaminhoInvertido
    ),
    reverse(CaminhoInvertido, Caminho).

bfs_evasivo(
    [[Destino | Resto] | _],
    _,
    Destino,
    _,
    [Destino | Resto]
) :-
    !.
bfs_evasivo(
    [[Atual | VisitadosNoCaminho] | Fila],
    VisitadosGlobais,
    Destino,
    Bloqueados,
    Caminho
) :-
    findall(Vizinho,
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, VisitadosGlobais),
          \+ memberchk(Vizinho, Bloqueados)
        ),
        Vizinhos0),

    sort(Vizinhos0, VizinhosUnicos),
    random_permutation(VizinhosUnicos, Vizinhos),

    findall(
        [Vizinho, Atual | VisitadosNoCaminho],
        member(Vizinho, Vizinhos),
        NovosCaminhos
    ),

    append(VisitadosGlobais, Vizinhos, NovosVisitados),
    append(Fila, NovosCaminhos, NovaFila),

    bfs_evasivo(
        NovaFila,
        NovosVisitados,
        Destino,
        Bloqueados,
        Caminho
    ).

% ============================================================
% VARIACAO DE CAMINHO E FUGA
% ============================================================

% Procura outro primeiro passo que preserve a distancia minima.
% Prefere nao usar o passo canonico nem voltar a cidade anterior.
passo_minimo_alternativo(Cidade, Destino, PassoCanonico, Proxima) :-
    distancia_bfs(Cidade, Destino, DistanciaAtual),
    DistanciaSeguinte is DistanciaAtual - 1,

    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          distancia_bfs(Vizinho, Destino, DistanciaSeguinte),
          Vizinho \== PassoCanonico,
          nao_eh_retorno(Vizinho)
        ),
        Alternativas0),

    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Proxima, Alternativas),
    !.
passo_minimo_alternativo(Cidade, Destino, PassoCanonico, Proxima) :-
    distancia_bfs(Cidade, Destino, DistanciaAtual),
    DistanciaSeguinte is DistanciaAtual - 1,

    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          distancia_bfs(Vizinho, Destino, DistanciaSeguinte),
          Vizinho \== PassoCanonico
        ),
        Alternativas0),

    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Proxima, Alternativas),
    !.
passo_minimo_alternativo(Cidade, Destino, _, Proxima) :-
    distancia_bfs(Cidade, Destino, DistanciaAtual),
    DistanciaSeguinte is DistanciaAtual - 1,

    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          distancia_bfs(Vizinho, Destino, DistanciaSeguinte),
          nao_eh_retorno(Vizinho)
        ),
        Alternativas0),

    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Proxima, Alternativas),
    !.
passo_minimo_alternativo(Cidade, Destino, _, Proxima) :-
    distancia_bfs(Cidade, Destino, DistanciaAtual),
    DistanciaSeguinte is DistanciaAtual - 1,

    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          distancia_bfs(Vizinho, Destino, DistanciaSeguinte)
        ),
        Alternativas0),

    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Proxima, Alternativas).

% Na fuga final, qualquer cidade diferente da cidade do tesouro
% encerra a partida. A prioridade e ser imprevisivel, nao seguir
% a primeira aresta do grafo e nao retornar imediatamente.
escolher_saida_imprevisivel(Cidade, PassoCanonico, Proxima) :-
    candidatos_saida(
        Cidade,
        PassoCanonico,
        sem_canonico_sem_retorno_nao_folha,
        Candidatos
    ),
    Candidatos \= [],
    random_member(Proxima, Candidatos),
    !.
escolher_saida_imprevisivel(Cidade, PassoCanonico, Proxima) :-
    candidatos_saida(
        Cidade,
        PassoCanonico,
        sem_canonico_sem_retorno,
        Candidatos
    ),
    Candidatos \= [],
    random_member(Proxima, Candidatos),
    !.
escolher_saida_imprevisivel(Cidade, PassoCanonico, Proxima) :-
    candidatos_saida(
        Cidade,
        PassoCanonico,
        sem_retorno_nao_folha,
        Candidatos
    ),
    Candidatos \= [],
    random_member(Proxima, Candidatos),
    !.
escolher_saida_imprevisivel(Cidade, _, Proxima) :-
    findall(Vizinho,
            aresta_conhecida(Cidade, Vizinho),
            Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    random_member(Proxima, Vizinhos).

candidatos_saida(
    Cidade,
    PassoCanonico,
    sem_canonico_sem_retorno_nao_folha,
    Candidatos
) :-
    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          Vizinho \== PassoCanonico,
          nao_eh_retorno(Vizinho),
          grau_cidade(Vizinho, Grau),
          Grau > 1
        ),
        Candidatos0),
    sort(Candidatos0, Candidatos).
candidatos_saida(
    Cidade,
    PassoCanonico,
    sem_canonico_sem_retorno,
    Candidatos
) :-
    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          Vizinho \== PassoCanonico,
          nao_eh_retorno(Vizinho)
        ),
        Candidatos0),
    sort(Candidatos0, Candidatos).
candidatos_saida(
    Cidade,
    _,
    sem_retorno_nao_folha,
    Candidatos
) :-
    findall(Vizinho,
        ( aresta_conhecida(Cidade, Vizinho),
          nao_eh_retorno(Vizinho),
          grau_cidade(Vizinho, Grau),
          Grau > 1
        ),
        Candidatos0),
    sort(Candidatos0, Candidatos).

nao_eh_retorno(Cidade) :-
    (   cidade_anterior(Anterior)
    ->  Cidade \== Anterior
    ;   true
    ).

grau_cidade(Cidade, Grau) :-
    findall(Vizinho,
            aresta_conhecida(Cidade, Vizinho),
            Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    length(Vizinhos, Grau).

registrar_saida(Cidade) :-
    retractall(cidade_anterior(_)),
    assertz(cidade_anterior(Cidade)).

% ============================================================
% BAIT STRATEGY
% ============================================================

% A cobertura completa de um segundo objetivo substitui a antiga
% isca de um unico item. Misturar as duas politicas acrescentaria
% roubos sem criar uma nova hipotese completa de tesouro.
configurar_bait_strategy(_) :-
    tesouro_cobertura(Cobertura),
    Cobertura \== nenhum,
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])),
    assertz(bait_usado),
    !.

% Escolhe um tesouro secundario de cadeia curta sem conhecer
% nomes de mapas, cidades, itens ou agentes adversarios.
configurar_bait_strategy(Target) :-
    findall(Quantidade-Tesouro,
        ( tesouro_conhecido(Tesouro, _, _),
          Tesouro \== Target,
          quantidade_requisitos_tesouro(Tesouro, Quantidade)
        ),
        Pares),

    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [MenorQuantidade-_ | _],

    findall(T,
            member(MenorQuantidade-T, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Isca, Melhores),

    assertz(tesouro_isca(Isca)),
    tesouro_conhecido(Isca, _, RequisitosIsca),
    requisitos_totais(RequisitosIsca, TodosItensIsca),
    assertz(itens_isca(TodosItensIsca)),
    !.
configurar_bait_strategy(_) :-
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])).

item_isca_disponivel(Cidade, Target, Itens, ItemIsca) :-
    itens_isca(ItensIsca),
    \+ prereqs_reais_prontos(Target, Itens),
    member(ItemIsca, ItensIsca),
    \+ memberchk(ItemIsca, Itens),
    \+ item_do_objetivo(ItemIsca, Target),
    item_conhecido(ItemIsca, Cidade, RequisitosIsca),
    requisitos_satisfeitos(RequisitosIsca, Itens).

cidade_isca_ativa(Cidade, Target, Itens, CidadeIsca) :-
    \+ bait_usado,
    itens_isca(ItensIsca),
    \+ prereqs_reais_prontos(Target, Itens),

    member(ItemIsca, ItensIsca),
    \+ memberchk(ItemIsca, Itens),
    \+ item_do_objetivo(ItemIsca, Target),

    item_conhecido(ItemIsca, CidadeIsca, RequisitosIsca),
    requisitos_satisfeitos(RequisitosIsca, Itens),

    proximo_objetivo(Target, Itens, ObjetivoReal),
    cidade_do_objeto(ObjetivoReal, CidadeReal),

    distancia_bfs(Cidade, CidadeIsca, D1),
    distancia_bfs(CidadeIsca, CidadeReal, D2),
    distancia_bfs(Cidade, CidadeReal, Direto),

    D1 + D2 - Direto =< 2,
    !.

prereqs_reais_prontos(Target, Itens) :-
    tesouro_conhecido(Target, _, Requisitos),
    subtract(Requisitos, [Target], PreRequisitos),
    forall(member(Requisito, PreRequisitos),
           memberchk(Requisito, Itens)).

% ============================================================
% DISFARCE FORTE
% ============================================================

% Gera varios planos para imitar prefixos de todos os outros
% suspeitos. Nao existe dependencia de IDs especificos.
preparar_planos_disfarce_forte(Suspeitos, IdReal) :-
    retractall(plano_disfarce_forte(_, _, _)),
    aparencia_suspeito(IdReal, Suspeitos, AparenciaReal),

    forall(
        ( aparencia_suspeito(IdIsca, Suspeitos, AparenciaIsca),
          IdIsca \== IdReal,
          tamanho_prefixo_comum(AparenciaReal, AparenciaIsca, Maximo),
          between(1, Maximo, TamanhoPrefixo),
          construir_plano_prefixo(
              AparenciaReal,
              AparenciaIsca,
              TamanhoPrefixo,
              Plano
          ),
          length(Plano, Custo),
          Custo >= 2,
          aplicar_plano_simulado(AparenciaReal, Plano, AparenciaFalsa),
          pontuar_aparencia_disfarcada(
              AparenciaFalsa,
              IdReal,
              Suspeitos,
              PontuacaoBase
          ),
          contar_omissoes(Plano, Omissoes),
          Pontuacao is
              PontuacaoBase +
              TamanhoPrefixo * 1000 -
              Custo * 30 -
              Omissoes * 250
        ),
        assertz(plano_disfarce_forte(
            Pontuacao,
            IdIsca,
            Plano
        ))
    ).

melhor_plano_disfarce_forte(
    PontosDisponiveis,
    MelhorPlano,
    Quantidade
) :-
    findall(Pontuacao-Plano,
        ( plano_disfarce_forte(Pontuacao, _, Plano),
          length(Plano, Custo),
          Custo =< PontosDisponiveis
        ),
        PlanosAplicaveis),

    PlanosAplicaveis \= [],
    keysort(PlanosAplicaveis, Ordenados),
    reverse(Ordenados, Descendentes),
    Descendentes = [MaiorPontuacao-_ | _],

    findall(Plano,
            member(MaiorPontuacao-Plano, Descendentes),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(MelhorPlano, Melhores),
    length(MelhorPlano, Quantidade).

% Constroi somente as modificacoes necessarias para fazer os
% primeiros N atributos se aproximarem da identidade-isca.
construir_plano_prefixo(
    AparenciaReal,
    AparenciaIsca,
    Quantidade,
    Plano
) :-
    primeiros_n(Quantidade, AparenciaReal, PrefixoReal),
    primeiros_n(Quantidade, AparenciaIsca, PrefixoIsca),
    construir_modificacoes_prefixo(
        PrefixoReal,
        PrefixoIsca,
        Plano
    ).

construir_modificacoes_prefixo([], [], []).
construir_modificacoes_prefixo(
    [Atributo | Reais],
    [Atributo | Iscas],
    Plano
) :-
    !,
    construir_modificacoes_prefixo(Reais, Iscas, Plano).
construir_modificacoes_prefixo(
    [AtributoReal | Reais],
    [AtributoIsca | Iscas],
    [trocar(AtributoReal, AtributoIsca) | Plano]
) :-
    mesmo_tipo_atributo(AtributoReal, AtributoIsca),
    !,
    construir_modificacoes_prefixo(Reais, Iscas, Plano).
construir_modificacoes_prefixo(
    [AtributoReal | Reais],
    [_ | Iscas],
    [omitir(AtributoReal) | Plano]
) :-
    construir_modificacoes_prefixo(Reais, Iscas, Plano).

mesmo_tipo_atributo(AtributoA, AtributoB) :-
    functor(AtributoA, Tipo, Aridade),
    functor(AtributoB, Tipo, Aridade).

contar_omissoes(Plano, Quantidade) :-
    findall(1,
            member(omitir(_), Plano),
            Omissoes),
    length(Omissoes, Quantidade).

marcar_disfarce_forte :-
    assertz(disfarce_forte_feito),
    retractall(disfarce_inicial_feito),
    assertz(disfarce_inicial_feito).

% ============================================================
% DISFARCE SIMPLES
% ============================================================

% Tenta primeiro uma troca valida nas tres primeiras posicoes e
% escolhe a que produz a melhor aparencia simulada.
escolher_disfarce_inicial(IdReal, Aparencia, MelhorModificacao) :-
    suspeitos_da_memoria(Suspeitos),
    primeiros_n(3, Aparencia, Primeiros),

    findall(Pontuacao-Modificacao,
        ( member(Original, Primeiros),
          valor_alternativo_mesmo_tipo(Original, Falso),
          Modificacao = trocar(Original, Falso),
          aplicar_plano_simulado(
              Aparencia,
              [Modificacao],
              AparenciaFalsa
          ),
          pontuar_aparencia_disfarcada(
              AparenciaFalsa,
              IdReal,
              Suspeitos,
              Pontuacao
          )
        ),
        Trocas),

    Trocas \= [],
    keysort(Trocas, Ordenadas),
    reverse(Ordenadas, Descendentes),
    Descendentes = [MaiorPontuacao-_ | _],
    findall(Mod,
            member(MaiorPontuacao-Mod, Descendentes),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(MelhorModificacao, Melhores),
    !.

% Se nenhuma troca valida existir, omite a primeira caracteristica.
escolher_disfarce_inicial(_, Aparencia, omitir(Primeiro)) :-
    primeiros_n(1, Aparencia, [Primeiro]).

valor_alternativo_mesmo_tipo(Original, Falso) :-
    suspeito_conhecido(Suspeito),
    atributos_do_suspeito(Suspeito, Atributos),
    member(Falso, Atributos),
    mesmo_tipo_atributo(Original, Falso),
    Falso \== Original.

% ============================================================
% SIMULACAO E PONTUACAO DE APARENCIA
% ============================================================

aplicar_plano_simulado(Aparencia, [], Aparencia).
aplicar_plano_simulado(Aparencia, [Modificacao | Resto], Resultado) :-
    aplicar_modificacao_simulada(
        Aparencia,
        Modificacao,
        AparenciaModificada
    ),
    aplicar_plano_simulado(
        AparenciaModificada,
        Resto,
        Resultado
    ).

aplicar_modificacao_simulada(
    Aparencia,
    trocar(Original, Falso),
    Resultado
) :-
    substituir_primeiro(Aparencia, Original, Falso, Resultado).
aplicar_modificacao_simulada(
    Aparencia,
    omitir(Original),
    Resultado
) :-
    substituir_primeiro(Aparencia, Original, none, Resultado).
aplicar_modificacao_simulada(
    Aparencia,
    adicionar(Novo),
    [Novo | Aparencia]
).

substituir_primeiro([Original | Resto], Original, Novo,
                    [Novo | Resto]) :-
    !.
substituir_primeiro([X | Resto], Original, Novo,
                    [X | Resultado]) :-
    substituir_primeiro(Resto, Original, Novo, Resultado).

% A pontuacao valoriza prefixos que impedem um mandato correto:
% - nenhum suspeito compativel;
% - mais de dois suspeitos compativeis;
% - apenas suspeitos incorretos compativeis.
% Prefixos iniciais recebem peso maior.
pontuar_aparencia_disfarcada(
    Aparencia,
    IdReal,
    Suspeitos,
    Pontuacao
) :-
    length(Aparencia, Tamanho),
    limite_pistas_avaliadas(Limite),
    Maximo is min(Tamanho, Limite),
    pontuar_prefixos(
        1,
        Maximo,
        Aparencia,
        IdReal,
        Suspeitos,
        0,
        Pontuacao
    ).

pontuar_prefixos(
    Posicao,
    Maximo,
    _,
    _,
    _,
    Acumulado,
    Acumulado
) :-
    Posicao > Maximo,
    !.
pontuar_prefixos(
    Posicao,
    Maximo,
    Aparencia,
    IdReal,
    Suspeitos,
    Acumulado,
    Pontuacao
) :-
    primeiros_n(Posicao, Aparencia, Observados),
    ids_compativeis(Observados, Suspeitos, IDs),
    pontuacao_conjunto_suspeitos(IDs, IdReal, Valor),
    peso_posicao(Posicao, Peso),
    NovoAcumulado is Acumulado + Valor * Peso,
    ProximaPosicao is Posicao + 1,
    pontuar_prefixos(
        ProximaPosicao,
        Maximo,
        Aparencia,
        IdReal,
        Suspeitos,
        NovoAcumulado,
        Pontuacao
    ).

pontuacao_conjunto_suspeitos([], _, 80) :- !.
pontuacao_conjunto_suspeitos(IDs, IdReal, 70) :-
    \+ memberchk(IdReal, IDs),
    !.
pontuacao_conjunto_suspeitos(IDs, _, Valor) :-
    length(IDs, Quantidade),
    Quantidade > 2,
    !,
    Valor is 40 + Quantidade.
pontuacao_conjunto_suspeitos([_], _, -80) :- !.
pontuacao_conjunto_suspeitos(_, _, -40).

peso_posicao(1, 10000) :- !.
peso_posicao(2, 3000) :- !.
peso_posicao(3, 1000) :- !.
peso_posicao(4, 300) :- !.
peso_posicao(_, 100).

ids_compativeis(Observados, Suspeitos, IDs) :-
    findall(Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          atributos_compativeis(Observados, Aparencia)
        ),
        IDs0),
    sort(IDs0, IDs).

atributos_compativeis([], _).
atributos_compativeis([Atributo | Resto], Aparencia) :-
    memberchk(Atributo, Aparencia),
    atributos_compativeis(Resto, Aparencia).

suspeitos_da_memoria(Suspeitos) :-
    findall(Suspeito,
            suspeito_conhecido(Suspeito),
            Suspeitos).

% ============================================================
% ESCOLHA DE IDENTIDADE
% ============================================================

% A pontuacao usa o mesmo modelo de compatibilidade empregado
% pelo motor para validar mandatos, mas da maior peso aos prefixos
% revelados nos primeiros roubos.
escolher_identidade(Suspeitos, LadraoID) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuacao_ambiguidade(
              Aparencia,
              Suspeitos,
              Pontuacao
          )
        ),
        Pares),

    keysort(Pares, Ordenados),
    reverse(Ordenados, Descendentes),
    Descendentes = [MaiorPontuacao-_ | _],

    findall(Id,
            member(MaiorPontuacao-Id, Descendentes),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(LadraoID, Melhores).

pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao) :-
    length(Aparencia, Tamanho),
    pontuar_ambiguidade_prefixos(
        1,
        Tamanho,
        Aparencia,
        Suspeitos,
        0,
        Pontuacao
    ).

pontuar_ambiguidade_prefixos(
    Posicao,
    Maximo,
    _,
    _,
    Acumulado,
    Acumulado
) :-
    Posicao > Maximo,
    !.
pontuar_ambiguidade_prefixos(
    Posicao,
    Maximo,
    Aparencia,
    Suspeitos,
    Acumulado,
    Pontuacao
) :-
    primeiros_n(Posicao, Aparencia, Prefixo),
    ids_compativeis(Prefixo, Suspeitos, IDs),
    length(IDs, Quantidade),
    peso_posicao(Posicao, Peso),
    NovoAcumulado is Acumulado + Quantidade * Peso,
    Proxima is Posicao + 1,
    pontuar_ambiguidade_prefixos(
        Proxima,
        Maximo,
        Aparencia,
        Suspeitos,
        NovoAcumulado,
        Pontuacao
    ).

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(Suspeito, Suspeitos),
    id_e_aparencia(Suspeito, Id, Aparencia).

id_e_aparencia(
    procurado(Id, _Nome, aparencia(Aparencia)),
    Id,
    Aparencia
) :-
    !.
id_e_aparencia(
    procurado(Id, aparencia(Aparencia)),
    Id,
    Aparencia
).

atributos_do_suspeito(
    procurado(_, _Nome, aparencia(Atributos)),
    Atributos
) :-
    !.
atributos_do_suspeito(
    procurado(_, aparencia(Atributos)),
    Atributos
).

% ============================================================
% ESCOLHA DE TESOURO
% ============================================================

% Randomiza entre tesouros empatados com a menor quantidade de
% requisitos recursivos, evitando uma escolha fixa desnecessaria.
escolher_tesouro(Tesouro) :-
    findall(Quantidade-T,
            quantidade_requisitos_tesouro(T, Quantidade),
            Pares),
    keysort(Pares, Ordenados),
    Ordenados = [MenorQuantidade-_ | _],
    findall(T,
            member(MenorQuantidade-T, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Tesouro, Melhores).

% Escolhe como cobertura o tesouro que acrescenta menos itens a cadeia
% do objetivo real. A metrica usa apenas dependencias, portanto vale
% para qualquer nome de mapa, cidade ou objeto.
configurar_tesouro_cobertura(Target, Grafo) :-
    tesouro_conhecido(Target, _, RequisitosTarget),
    requisitos_totais(RequisitosTarget, ItensTarget),
    length(ItensTarget, CustoTarget),
    quantidade_cidades_grafo(Grafo, QuantidadeCidades),
    findall(CustoAdicional-CustoUniao-Tesouro,
        ( tesouro_conhecido(Tesouro, _, Requisitos),
          Tesouro \== Target,
          cadeia_resolvivel(Requisitos),
          requisitos_totais(Requisitos, ItensCobertura),
          subtract(ItensCobertura, ItensTarget, Adicionais),
          length(Adicionais, CustoAdicional),
          append(ItensTarget, ItensCobertura, Uniao0),
          sort(Uniao0, Uniao),
          length(Uniao, CustoUniao),
          cobertura_cabe_no_mapa(
              CustoAdicional,
              CustoTarget,
              CustoUniao,
              QuantidadeCidades
          )
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [MenorAdicional-MenorUniao-_ | _],
    findall(T,
            member(MenorAdicional-MenorUniao-T, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Cobertura, Melhores),
    assertz(tesouro_cobertura(Cobertura)),
    !.
configurar_tesouro_cobertura(_, _) :-
    assertz(tesouro_cobertura(nenhum)).

cobertura_cabe_no_mapa(CustoAdicional, CustoTarget, _, _) :-
    CustoAdicional =< CustoTarget,
    !.
cobertura_cabe_no_mapa(_, _, CustoUniao, QuantidadeCidades) :-
    CustoUniao * 3 =< QuantidadeCidades.

quantidade_cidades_grafo(Grafo, Quantidade) :-
    findall(Cidade,
        ( member(adj(A, B), Grafo),
          ( Cidade = A
          ; Cidade = B
          )
        ),
        Cidades0),
    sort(Cidades0, Cidades),
    length(Cidades, Quantidade).

quantidade_requisitos_tesouro(Tesouro, Quantidade) :-
    tesouro_conhecido(Tesouro, _, Requisitos),
    cadeia_resolvivel(Requisitos),
    requisitos_totais(Requisitos, Todos),
    length(Todos, Quantidade).

% Um tesouro so e candidato quando cada requisito terminal existe
% como item no preload. Isso evita escolher objetivos impossiveis em
% cenarios incompletos e tambem interrompe ciclos de dependencias.
cadeia_resolvivel(Requisitos) :-
    cadeia_resolvivel(Requisitos, []).

cadeia_resolvivel([], _).
cadeia_resolvivel([Requisito | Resto], Visitados) :-
    \+ memberchk(Requisito, Visitados),
    item_conhecido(Requisito, _, SubRequisitos),
    cadeia_resolvivel(SubRequisitos, [Requisito | Visitados]),
    cadeia_resolvivel(Resto, Visitados).

requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Requisito,
            requisito_recursivo(Requisitos, Requisito),
            Todos),
    sort(Todos, TodosUnicos).

requisito_recursivo(Requisitos, Requisito) :-
    member(Requisito, Requisitos).
requisito_recursivo(Requisitos, RequisitoIndireto) :-
    member(Requisito, Requisitos),
    item_conhecido(Requisito, _, SubRequisitos),
    requisito_recursivo(SubRequisitos, RequisitoIndireto).

% ============================================================
% REQUISITOS E PROXIMO OBJETIVO
% ============================================================

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Requisito | Resto], Itens) :-
    memberchk(Requisito, Itens),
    requisitos_satisfeitos(Resto, Itens).

proximo_objetivo(Target, Itens, ProximoObjeto) :-
    tesouro_planejado(Target, Itens, Planejado),
    tesouro_conhecido(Planejado, _, Requisitos),
    requisito_pendente(Requisitos, Itens, Requisito),
    !,
    resolver_requisito(Requisito, Itens, ProximoObjeto).
proximo_objetivo(Target, _, Target).

% Prepara primeiro todos os requisitos do objetivo-cobertura, sem
% roubar esse tesouro. Depois conclui apenas o objetivo real.
tesouro_planejado(_, Itens, Cobertura) :-
    tesouro_cobertura(Cobertura),
    Cobertura \== nenhum,
    tesouro_conhecido(Cobertura, _, Requisitos),
    \+ requisitos_satisfeitos(Requisitos, Itens),
    !.
tesouro_planejado(Target, _, Target).

atualizar_cidade_cobertura_perigosa(Itens) :-
    tesouro_cobertura(Cobertura),
    Cobertura \== nenhum,
    tesouro_conhecido(Cobertura, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    retractall(cidade_cobertura_perigosa(_)),
    assertz(cidade_cobertura_perigosa(Cidade)),
    !.
atualizar_cidade_cobertura_perigosa(_).

% Mantem uma crenca conservadora sobre os bloqueios que podem ser
% produzidos por politicas reativas. O modelo usa apenas o mapa e o
% inventario, sem identificar o agente adversario.
atualizar_modelo_bloqueios(CidadeRoubo, Itens) :-
    retractall(origem_roubo_recente(_)),
    assertz(origem_roubo_recente(CidadeRoubo)),
    atualizar_fila_vizinhos_prevista(CidadeRoubo),
    atualizar_armadilha_gulosa(CidadeRoubo, Itens).

atualizar_fila_vizinhos_prevista(CidadeRoubo) :-
    findall(Score-Vizinho,
        ( aresta_conhecida(CidadeRoubo, Vizinho),
          \+ cidade_ja_bloqueada_prevista(Vizinho),
          grau_cidade(Vizinho, Grau),
          Score is -Grau
        ),
        Pares),
    keysort(Pares, Ordenados),
    findall(Vizinho,
            member(_-Vizinho, Ordenados),
            Fila),
    retractall(fila_bloqueios_prevista(_)),
    assertz(fila_bloqueios_prevista(Fila)),
    retractall(bloqueio_persistente_previsto(_)).

proximo_bloqueio_previsto(Cidade) :-
    fila_bloqueios_prevista([Cidade | _]),
    !.
proximo_bloqueio_previsto(Cidade) :-
    bloqueio_persistente_previsto(Cidade).

avancar_modelo_bloqueios :-
    fila_bloqueios_prevista([Cidade | Resto]),
    !,
    retractall(fila_bloqueios_prevista(_)),
    assertz(fila_bloqueios_prevista(Resto)),
    (   cidade_ja_bloqueada_prevista(Cidade)
    ->  true
    ;   assertz(cidade_ja_bloqueada_prevista(Cidade))
    ),
    retractall(bloqueio_persistente_previsto(_)),
    (   Resto == []
    ->  assertz(bloqueio_persistente_previsto(Cidade))
    ;   true
    ).
avancar_modelo_bloqueios.

inicializar_armadilha_gulosa :-
    findall(Score-Cidade,
        ( objeto_disponivel_previsto([], Objeto),
          cidade_do_objeto(Objeto, Cidade),
          grau_cidade(Cidade, Grau),
          dependencia_restante_prevista(Objeto, [], Restante),
          Score is Restante * 10 - Grau
        ),
        Pares),
    keysort(Pares, [_-Cidade | _]),
    assertz(armadilha_gulosa_prevista(Cidade)),
    !.
inicializar_armadilha_gulosa.

atualizar_armadilha_gulosa(Cidade, Itens) :-
    retractall(armadilha_gulosa_prevista(_)),
    melhor_alvo_previsto(Cidade, Itens, CidadeAlvo),
    (   Cidade == CidadeAlvo
    ->  Armadilha = Cidade
    ;   caminho_mais_curto(Cidade, CidadeAlvo,
                           [Cidade, Armadilha | _])
    ),
    assertz(armadilha_gulosa_prevista(Armadilha)),
    !.
atualizar_armadilha_gulosa(_, _) :-
    retractall(armadilha_gulosa_prevista(_)).

melhor_alvo_previsto(Cidade, Itens, CidadeAlvo) :-
    findall(Score-Objeto-CidadeObjeto,
        ( objeto_disponivel_previsto(Itens, Objeto),
          cidade_do_objeto(Objeto, CidadeObjeto),
          caminho_mais_curto(Cidade, CidadeObjeto, Caminho),
          length(Caminho, Tamanho),
          dependencia_restante_prevista(Objeto, Itens, Restante),
          Score is Tamanho * 10 + Restante * 4
        ),
        Pares),
    keysort(Pares, [_-_-CidadeAlvo | _]).

objeto_disponivel_previsto(Itens, Tesouro) :-
    tesouro_conhecido(Tesouro, _, Requisitos),
    \+ memberchk(Tesouro, Itens),
    requisitos_satisfeitos(Requisitos, Itens).
objeto_disponivel_previsto(Itens, Item) :-
    item_relevante_previsto(Item),
    \+ memberchk(Item, Itens),
    item_conhecido(Item, _, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens).

item_relevante_previsto(Item) :-
    tesouro_conhecido(_, _, Requisitos),
    requisito_recursivo(Requisitos, Item).

dependencia_restante_prevista(Objeto, Itens, Restante) :-
    tesouro_conhecido(Objeto, _, Requisitos),
    !,
    requisitos_totais(Requisitos, Todos),
    subtract(Todos, Itens, Pendentes),
    length(Pendentes, Restante).
dependencia_restante_prevista(Objeto, Itens, Restante) :-
    item_conhecido(Objeto, _, Requisitos),
    requisitos_totais(Requisitos, Todos),
    subtract(Todos, Itens, Pendentes),
    length(Pendentes, Restante).

resolver_requisito(Item, Itens, ProximoObjeto) :-
    item_conhecido(Item, _, Requisitos),
    requisito_pendente(Requisitos, Itens, Requisito),
    !,
    resolver_requisito(Requisito, Itens, ProximoObjeto).
resolver_requisito(Item, _, Item).

requisito_pendente([Requisito | _], Itens, Requisito) :-
    \+ memberchk(Requisito, Itens),
    !.
requisito_pendente([_ | Resto], Itens, Pendente) :-
    requisito_pendente(Resto, Itens, Pendente).

cidade_do_objeto(Objeto, Cidade) :-
    item_conhecido(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_conhecido(Objeto, Cidade, _).

item_do_objetivo(Item, Target) :-
    tesouro_conhecido(Target, _, Requisitos),
    requisito_recursivo(Requisitos, Item).

% ============================================================
% BFS
% ============================================================

proximo_passo(Origem, Destino, ProximaCidade) :-
    caminho_mais_curto(
        Origem,
        Destino,
        [Origem, ProximaCidade | _]
    ).

caminho_mais_curto(Origem, Destino, Caminho) :-
    bfs(
        [[Origem]],
        [Origem],
        Destino,
        CaminhoInvertido
    ),
    reverse(CaminhoInvertido, Caminho).

bfs([[Destino | Resto] | _], _, Destino,
    [Destino | Resto]) :-
    !.
bfs([CaminhoAtual | OutrosCaminhos], Visitados,
    Destino, Caminho) :-
    estender_caminho(
        CaminhoAtual,
        Visitados,
        NovosCaminhos,
        NovosVizinhos
    ),
    append(Visitados, NovosVizinhos, VisitadosAtualizados),
    append(OutrosCaminhos, NovosCaminhos, FilaAtualizada),
    bfs(
        FilaAtualizada,
        VisitadosAtualizados,
        Destino,
        Caminho
    ).

estender_caminho(
    [Atual | VisitadosNoCaminho],
    JaVistos,
    NovosCaminhos,
    NovosVizinhos
) :-
    findall(Vizinho,
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        Vizinhos0),
    sort(Vizinhos0, NovosVizinhos),
    findall(
        [Vizinho, Atual | VisitadosNoCaminho],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos
    ).

distancia_bfs(Origem, Destino, 0) :-
    Origem == Destino,
    !.
distancia_bfs(Origem, Destino, Distancia) :-
    bfs_dist(
        [[Origem, 0]],
        [Origem],
        Destino,
        Distancia
    ).

bfs_dist([[Destino, Distancia] | _], _, Destino,
         Distancia) :-
    !.
bfs_dist([[Atual, Distancia] | Fila], Visitados,
         Destino, Resultado) :-
    DistanciaSeguinte is Distancia + 1,

    findall([Vizinho, DistanciaSeguinte],
        ( aresta_conhecida(Atual, Vizinho),
          \+ memberchk(Vizinho, Visitados)
        ),
        Novos0),

    sort(Novos0, Novos),
    findall(Vizinho,
            member([Vizinho, _], Novos),
            NovosVizinhos),

    append(Visitados, NovosVizinhos, VisitadosAtualizados),
    append(Fila, Novos, FilaAtualizada),

    bfs_dist(
        FilaAtualizada,
        VisitadosAtualizados,
        Destino,
        Resultado
    ).

% ============================================================
% UTILITARIOS E LIMPEZA
% ============================================================

lembrar_aresta(A, B) :-
    (   aresta_conhecida(A, B)
    ->  true
    ;   assertz(aresta_conhecida(A, B))
    ),
    (   aresta_conhecida(B, A)
    ->  true
    ;   assertz(aresta_conhecida(B, A))
    ).

primeiros_n(N, Lista, Primeiros) :-
    N > 0,
    length(Lista, Tamanho),
    Quantidade is min(N, Tamanho),
    length(Primeiros, Quantidade),
    append(Primeiros, _, Lista),
    !.
primeiros_n(_, _, []).

tamanho_prefixo_comum(A, B, Tamanho) :-
    length(A, TA),
    length(B, TB),
    Tamanho is min(TA, TB).

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),

    retractall(tesouro_isca(_)),
    retractall(itens_isca(_)),
    retractall(bait_usado),
    retractall(tesouro_cobertura(_)),
    retractall(cidade_cobertura_perigosa(_)),
    retractall(fila_bloqueios_prevista(_)),
    retractall(bloqueio_persistente_previsto(_)),
    retractall(cidade_ja_bloqueada_prevista(_)),
    retractall(armadilha_gulosa_prevista(_)),
    retractall(origem_roubo_recente(_)),

    retractall(plano_disfarce_forte(_, _, _)),
    retractall(disfarce_forte_feito),
    retractall(disfarce_inicial_feito),

    retractall(cidade_anterior(_)),
    retractall(total_itens_observado(_)),
    retractall(rota_evasiva(_)),
    retractall(destino_rota_evasiva(_)),
    retractall(rota_bfs_prevista(_)),
    retractall(escolha_diversificada(_, _, _)).
