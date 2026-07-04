% ============================================================
% AGENTE LADRAO: raffles_v8
%
% Base do raffles_v7 (ataque destravado + ambiguidade que ganha o
% marpled 100%) + a CAMADA DE EVASAO AGNOSTICA do ladrao_raffles.pl,
% que e o que ganha partidas da familia de bloqueadores (shortestd,
% neighborblockd, blockerd) onde o v7 fazia 0%.
%
% Filosofia da evasao (licao do ladrao_raffles, oposta ao que o v8
% anterior fez errado):
%  - Modela a UNIAO de padroes de bloqueio, sem adivinhar o oponente:
%    armadilha golosa (shortestd), fila de vizinhos que avanca 1/turno
%    (neighborblockd) e cidade do ultimo roubo (blockerd).
%  - Rerroteia o PASSO de forma SOFT e fail-safe: so desvia se ha
%    caminho limpo ate o MESMO destino; se o destino e perigoso ou nao
%    ha desvio, cai no passo normal (aceita o risco). NUNCA recusa
%    objetivo nem bloqueia rigido -> nao paralisa (a paralisia empatava
%    e foi o erro do v8 anterior).
%
% (Descricao do nucleo v7 herdada abaixo.)
% Fork do raffles_v6, focado nos dois detetives META (marpled + shortestd).
% Mudancas em relacao ao v6:
%
%  A. ATAQUE DESTRAVADO. O v6 so roubava o alvo depois de "cobertura
%     global pronta" (roubar quase todo o mapa), o que estourava o
%     orcamento de turnos e transformava vitorias em empates. O v7
%     rouba o alvo assim que: a cadeia real esta completa, ha
%     ambiguidade suficiente (>= 1 outra cadeia de tesouro completa; 2
%     quando o orcamento de turnos e folgado) e existe rota de fuga.
%     Ter >= 2 tesouros "prontos" derruba o mp_ready_target do marpled,
%     que so fecha com candidato UNICO. So coleta os itens necessarios
%     (cadeia real + baits), nao o mapa inteiro.
%
%  B. MOVIMENTO ENXUTO. Removida a maquinaria que paralisava o v6
%     (desvio_final, penalidade de conectividade no passo, anti-minimo
%     generico, evitar toda cidade de tesouro pronta). O v7 anda pelo
%     caminho minimo e so desvia do passo EXATO que o detetive tranca.
%
%  C. EVASAO DIRIGIDA AO shortestd. O ladrao roda dentro de si a
%     predicao do shortestd (mesmo mapa, mesmos eventos, mesmo turno ->
%     mesma trava) e, se o passo canonico cairia justo na celula que o
%     shortestd vai fechar, desvia para outro passo minimo de mesmo
%     custo rumo ao mesmo destino. Ideia herdada do evasort.pl.
%     LIMITE: so evita a trava NOVA de cada turno, nao a trava
%     persistente do engine (evitar a persistente venceria mais partidas
%     do shortestd mas paralisa contra o marpled) -> shortestd continua
%     dificil. marpled: 0%->100% (map-independent).
%
%  Mantido do v6: identidade ambigua + tres disfarces, escolha do
%  tesouro-alvo e a disciplina de diversificacao de cadeias (segurar o
%  ultimo item real ate a ambiguidade valer) que neutraliza o marpled.
% ============================================================

:- module(raffles_v8, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- dynamic aresta/2.
:- dynamic item_mem/3.
:- dynamic tesouro_mem/3.
:- dynamic suspeito_mem/1.

:- dynamic disfarce_feito/0.
:- dynamic itens_necessarios_mem/1.
:- dynamic cidade_anterior/1.

% Eventos vistos neste turno, a trava NOVA do turno e a trava ATIVA
% persistente (armadilha golosa do shortestd).
:- dynamic eventos_turno/1.
:- dynamic trava_turno/1.
:- dynamic trava_ativa/1.

% Modelo agnostico de bloqueio (uniao de padroes da familia):
%  - fila_bloqueios: vizinhos do ultimo roubo, 1 por turno (neighborblockd)
%  - bloqueio_persistente: ultimo da fila, que fica travado
%  - origem_roubo_recente: cidade do ultimo roubo (blockerd)
%  - cidade_ja_bloqueada / ultimo_roubo_cidade: memoria auxiliar
:- dynamic fila_bloqueios/1.
:- dynamic bloqueio_persistente/1.
:- dynamic origem_roubo_recente/1.
:- dynamic cidade_ja_bloqueada/1.
:- dynamic ultimo_roubo_cidade/1.

% Espelho da predicao do shortestd (memoria PROPRIA, prefixo sd_):
% mesmo mapa, mesmos eventos, mesmo turno => mesma trava. Nunca toca no
% modulo shortestd real, entao funciona mesmo quando o adversario e ele.
:- dynamic sd_edge/2.
:- dynamic sd_item/3.
:- dynamic sd_treasure/3.
:- dynamic sd_lock/1.

% Faixa de conectividade penalizada (suave) no inicio da partida:
% graus muito baixos/altos recebem penalidade na escolha de item.
grau_baixo_limite(1).
grau_alto_limite(5).

% Quantos passos extras um desvio evasivo pode custar. Teto contra
% paralisia em mapas apertados (ver passo_evitando_riscos).
folga_desvio(3).

% ============================================================
% PRELOAD
% ============================================================

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, Objetivo) :-
    limpar_memoria,

    forall(member(adj(A, B), Grafo),
           lembrar_aresta(A, B)),

    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_mem(Item, Cidade, Requisitos))),

    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_mem(Tesouro, Cidade, Requisitos))),

    forall(member(Suspeito, Suspeitos),
           assertz(suspeito_mem(Suspeito))),

    % Espelho do shortestd: arestas na MESMA ordem que o detetive
    % (adj(A,B) -> (A,B) e (B,A)), itens e tesouros crus.
    forall(member(adj(A, B), Grafo),
           ( assertz(sd_edge(A, B)), assertz(sd_edge(B, A)) )),
    forall(member(item(I, C, R), Itens),
           assertz(sd_item(I, C, R))),
    forall(member(tesouro(T, C, R), Tesouros),
           assertz(sd_treasure(T, C, R))),

    escolher_identidade(Suspeitos, LadraoID),
    escolher_tesouro(Objetivo),
    definir_plano_coleta(Objetivo),

    assertz(fila_bloqueios([])).

% Conjunto de itens que a estrategia realmente precisa: a cadeia do
% alvo mais as `Alvo` cadeias de bait mais baratas (as que geram a
% ambiguidade). Coletar so isso faz o ladrao ir direto ao ponto em vez
% de raspar o mapa inteiro (o que empatava por falta de turnos).
definir_plano_coleta(Target) :-
    baits_alvo(Target, Alvo),
    findall(Custo-T,
        ( tesouro_mem(T, _, Req),
          T \== Target,
          cadeia_resolvivel(Req),
          requisitos_totais(Req, Cadeia),
          length(Cadeia, Custo)
        ),
        Pares),
    keysort(Pares, Ordenados),
    primeiros_n(Alvo, Ordenados, EscolhidosPares),
    findall(B, member(_-B, EscolhidosPares), Baits),
    tesouro_mem(Target, _, ReqTarget),
    requisitos_totais(ReqTarget, ItensReais),
    findall(I,
        ( member(B, Baits),
          tesouro_mem(B, _, ReqB),
          requisitos_totais(ReqB, ItensB),
          member(I, ItensB)
        ),
        ItensBaits),
    append(ItensReais, ItensBaits, Todos),
    sort(Todos, Necessarios),
    retractall(itens_necessarios_mem(_)),
    assertz(itens_necessarios_mem(Necessarios)).

% ============================================================
% ACAO PRINCIPAL
% ============================================================

ladrao_action(Eventos, Estado, AcaoFinal) :-
    registrar_eventos(Eventos),
    prever_trava_shortestd(Eventos),
    atualizar_modelo_bloqueios(Eventos),
    decidir_acao(Estado, AcaoInicial),
    adaptar_movimento(Estado, AcaoInicial, AcaoFinal),
    avancar_modelo_bloqueios,
    !.
ladrao_action(_, _, nada).

registrar_eventos(Eventos) :-
    retractall(eventos_turno(_)),
    assertz(eventos_turno(Eventos)).

% Calcula a cidade que o shortestd vai trancar NESTE turno e a espelha
% (como o detetive faz lembrar_lock), para a predicao dos proximos
% turnos considerar as cidades ja trancadas. Guarda em trava_turno/1.
prever_trava_shortestd(Eventos) :-
    retractall(trava_turno(_)),
    (   sd_predict(Eventos, Cidade)
    ->  ( sd_lock(Cidade) -> true ; assertz(sd_lock(Cidade)) ),
        assertz(trava_turno(Cidade)),
        retractall(trava_ativa(_)),
        assertz(trava_ativa(Cidade))
    ;   assertz(trava_turno(nenhum))
    ).

% Trava do shortestd NESTE turno (nova); usada na fuga.
lock_evasao(Lock) :-
    ( trava_turno(L), L \== nenhum -> Lock = L ; Lock = nenhum ).

% ============================================================
% MODELO AGNOSTICO DE BLOQUEIO (uniao de padroes da familia)
% ============================================================
% Nao identifica o oponente: mantem uma crenca conservadora sobre quais
% cidades podem estar/ficar trancadas, a partir so do mapa e dos roubos.

% A cada roubo NOVO (visto nos eventos, ja com o delay do engine),
% reancora os modelos reativos na cidade do roubo.
atualizar_modelo_bloqueios(Eventos) :-
    ultimo_roubo_evento(Eventos, Cidade),
    \+ ultimo_roubo_cidade(Cidade),
    !,
    retractall(ultimo_roubo_cidade(_)),
    assertz(ultimo_roubo_cidade(Cidade)),
    retractall(origem_roubo_recente(_)),
    assertz(origem_roubo_recente(Cidade)),
    atualizar_fila_vizinhos(Cidade).
atualizar_modelo_bloqueios(_).

ultimo_roubo_evento([roubo(_, Cidade, _) | _], Cidade) :- !.
ultimo_roubo_evento([_ | Resto], Cidade) :-
    ultimo_roubo_evento(Resto, Cidade).

% Fila de vizinhos do roubo, grau crescente (igual ao neighborblockd).
atualizar_fila_vizinhos(CidadeRoubo) :-
    findall(Score-Vizinho,
        ( aresta(CidadeRoubo, Vizinho),
          \+ cidade_ja_bloqueada(Vizinho),
          grau_cidade(Vizinho, Grau),
          Score is -Grau
        ),
        Pares),
    keysort(Pares, Ordenados),
    findall(Vizinho, member(_-Vizinho, Ordenados), Fila),
    retractall(fila_bloqueios(_)),
    assertz(fila_bloqueios(Fila)),
    retractall(bloqueio_persistente(_)).

% Cidade que a fila-de-vizinhos fecha AGORA (ou a persistente restante).
proximo_bloqueio_previsto(Cidade) :-
    fila_bloqueios([Cidade | _]),
    !.
proximo_bloqueio_previsto(Cidade) :-
    bloqueio_persistente(Cidade).

% No fim do turno, "consome" a fila 1 por turno (como o detetive fecha).
avancar_modelo_bloqueios :-
    fila_bloqueios([Cidade | Resto]),
    !,
    retractall(fila_bloqueios(_)),
    assertz(fila_bloqueios(Resto)),
    ( cidade_ja_bloqueada(Cidade) -> true ; assertz(cidade_ja_bloqueada(Cidade)) ),
    retractall(bloqueio_persistente(_)),
    ( Resto == [] -> assertz(bloqueio_persistente(Cidade)) ; true ).
avancar_modelo_bloqueios.

% Uniao das cidades a evitar como PASSAGEM (best-effort; ver movimento).
cidade_a_evitar(Cidade) :-
    trava_ativa(Cidade),
    Cidade \== nenhum.
cidade_a_evitar(Cidade) :-
    proximo_bloqueio_previsto(Cidade).
cidade_a_evitar(Cidade) :-
    origem_roubo_recente(Cidade).

% ============================================================
% DECISAO
% ============================================================

% PRIORIDADE MAXIMA: se a celula onde estou sera trancada NESTE turno
% (o detetive fecha DEPOIS do ladrao andar), saio dela agora. Cobre o
% "comecar em cima da primeira trava do shortestd" (que mata ate o
% ladrao_raffles ~50% das vezes). Vale mais que disfarcar/roubar.
decidir_acao(
    thief(loc(Cidade), _, _, _, _, _),
    move(Cidade, Proxima)
) :-
    trava_turno(Cidade),
    fuga_da_trava(Cidade, Proxima),
    !.

% Usa tres modificacoes no primeiro turno.
decidir_acao(
    thief(_, Id, aparencia(Aparencia), _, Itens, Pontos),
    disfarce(Modificacoes)
) :-
    Itens == [],
    \+ disfarce_feito,
    Pontos >= 3,
    escolher_tres_disfarces(Id, Aparencia, Modificacoes),
    length(Modificacoes, 3),
    assertz(disfarce_feito),
    !.

% Fallback caso o cenario ofereca menos de tres pontos.
decidir_acao(
    thief(_, Id, aparencia(Aparencia), _, Itens, Pontos),
    disfarce(Modificacoes)
) :-
    Itens == [],
    \+ disfarce_feito,
    Pontos > 0,
    escolher_tres_disfarces(Id, Aparencia, Todas),
    primeiros_n(Pontos, Todas, Modificacoes),
    assertz(disfarce_feito),
    !.

% Depois do tesouro, sai aleatoriamente.
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, Vizinho)
) :-
    memberchk(Target, Itens),
    aresta(Cidade, Vizinho),
    !.

% O tesouro real so e roubado quando:
% - seus requisitos estao completos;
% - todos os itens nao reservados ja foram roubados.
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    roubar(Target)
) :-
    pode_roubar_tesouro_final(Target, Cidade, Itens),
    !.

% Cadeia real + ambiguidade ja prontas: PARA de coletar e vai ao alvo.
% (Fica antes das clausulas de coleta para nao estourar o orcamento de
% turnos roubando itens que a estrategia nao exige mais.)
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, Proxima)
) :-
    pode_iniciar_aproximacao_final(Target, Itens),
    tesouro_mem(Target, Destino, _),
    Cidade \== Destino,
    proximo_passo(Cidade, Destino, Proxima),
    !.

% Rouba o melhor item disponivel da cobertura global.
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    roubar(Item)
) :-
    proximo_item_cobertura(Cidade, Target, Itens, Item),
    item_mem(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.

% Caminha ate o melhor item disponivel.
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, Proxima)
) :-
    proximo_item_cobertura(Cidade, Target, Itens, Item),
    cidade_objeto(Item, Destino),
    proximo_passo(Cidade, Destino, Proxima),
    !.

% Guarda de recuperacao: este estado nao deve ocorrer pelo planejamento,
% mas, se o ladrao estiver na cidade do alvo antes de poder rouba-lo,
% ele tenta sair para uma cidade comum. Isso evita o antigo `nada`
% causado por estar exatamente no destino sem satisfazer roubar/1.
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, Proxima)
) :-
    tesouro_mem(Target, Cidade, _),
    \+ pode_roubar_tesouro_final(Target, Cidade, Itens),
    vizinho_comum_preferido(Cidade, Proxima),
    !.

decidir_acao(_, nada).

% ============================================================
% ROUBO DO ALVO E AMBIGUIDADE
% ============================================================

% Alvo roubavel quando: a cadeia real esta completa, ha ambiguidade
% suficiente (>= 2 outras cadeias completas) e existe rota de fuga.
% NAO exige mais "cobertura global" (roubar o mapa inteiro).
pode_roubar_tesouro_final(Target, Cidade, Inventario) :-
    tesouro_mem(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Inventario),
    ambiguidade_suficiente(Target, Inventario),
    existe_rota_fuga(Cidade).

% Pode largar a coleta e partir para o alvo quando a cadeia real e a
% ambiguidade ja estao prontas (a fuga e verificada ao chegar la).
pode_iniciar_aproximacao_final(Target, Inventario) :-
    tesouro_mem(Target, _, Requisitos),
    requisitos_satisfeitos(Requisitos, Inventario),
    ambiguidade_suficiente(Target, Inventario).

% >= 2 tesouros DIFERENTES do alvo com a cadeia completa derrubam o
% mp_ready_target do marpled (que so fecha com candidato UNICO) e dao
% ao detetive-por-alvo no maximo 1/3 de chance. Se o mapa nao comportar
% 2 baits, exige o maximo de baits resolviveis.
ambiguidade_suficiente(Target, Inventario) :-
    baits_completos(Target, Inventario, N),
    baits_alvo(Target, Alvo),
    N >= Alvo.

% Quantos baits completar: 2 quando ha folga de turnos (contra um
% detetive que campa ao acaso um tesouro-pronto, 2 baits dao no maximo
% 1/3 de chance); 1 quando o mapa e curto. Contra o marpled 1 bait ja
% basta (alvo + 1 bait = 2 tesouros prontos derrubam o mp_ready_target,
% que exige candidato UNICO), e exigir 2 num mapa curto so empataria
% por falta de tempo. Nunca mais que os baits possiveis.
baits_alvo(Target, Alvo) :-
    baits_possiveis(Target, Max),
    ( orcamento_folgado -> Ideal = 2 ; Ideal = 1 ),
    Alvo is min(Ideal, Max).

orcamento_folgado :-
    catch(user:max_turnos(MT), _, fail),
    findall(x, item_mem(_, _, _), Itens),
    length(Itens, NItens),
    MT >= NItens * 3.

baits_completos(Target, Inventario, N) :-
    findall(T,
        ( tesouro_mem(T, _, Req),
          T \== Target,
          requisitos_satisfeitos(Req, Inventario)
        ),
        Ts),
    sort(Ts, U),
    length(U, N).

baits_possiveis(Target, Max) :-
    findall(T,
        ( tesouro_mem(T, _, Req),
          T \== Target,
          cadeia_resolvivel(Req)
        ),
        Ts),
    sort(Ts, U),
    length(U, Max).

% Ha para onde fugir apos o roubo (pelo menos um vizinho da cidade).
existe_rota_fuga(Cidade) :-
    aresta(Cidade, _),
    !.


% Seleciona entre todos os itens atualmente roubaveis e necessarios.
% A prioridade e evitar que, apos o roubo, reste uma unica acao
% disponivel que dependa diretamente do item recem-roubado.
proximo_item_cobertura(Cidade, Target, Inventario, MelhorItem) :-
    itens_disponiveis_cobertura(Inventario, Disponiveis0),
    Disponiveis0 \= [],
    candidatos_respeitando_isca(
        Target,
        Inventario,
        Disponiveis0,
        Disponiveis
    ),
    pontuar_candidatos(
        Disponiveis,
        Cidade,
        Target,
        Inventario,
        Pares
    ),
    keysort(Pares, Ordenados),
    Ordenados = [MelhorPontuacao-_ | _],
    findall(Item,
            member(MelhorPontuacao-Item, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(MelhorItem, Melhores).

itens_disponiveis_cobertura(Inventario, Disponiveis) :-
    itens_necessarios_mem(Necessarios),
    findall(Item,
        ( item_mem(Item, _, Requisitos),
          memberchk(Item, Necessarios),
          \+ memberchk(Item, Inventario),
          requisitos_satisfeitos(Requisitos, Inventario)
        ),
        Disponiveis0),
    sort(Disponiveis0, Disponiveis).

% Antes de completar a cadeia verdadeira, exige pelo menos uma
% cadeia-isca completa. O item que fecharia a cadeia real fica
% temporariamente fora da lista sempre que houver outra opcao.
candidatos_respeitando_isca(
    Target,
    Inventario,
    Disponiveis,
    Disponiveis
) :-
    ambiguidade_suficiente(Target, Inventario),
    !.

% Sem uma isca pronta, o ultimo requisito real fica proibido.
% Entre os demais itens, prioriza os que avancam alguma cadeia falsa.
candidatos_respeitando_isca(
    Target,
    Inventario,
    Disponiveis,
    Filtrados
) :-
    findall(Item,
        ( member(Item, Disponiveis),
          \+ item_completa_cadeia_real(
              Item,
              Target,
              Inventario
          ),
          item_avanca_cadeia_isca(
              Item,
              Target,
              Inventario
          )
        ),
        Iscas0),
    sort(Iscas0, Iscas),
    Iscas \= [],
    Filtrados = Iscas,
    !.

% Se nenhum item disponivel avancar diretamente uma isca, ainda pode
% coletar outro item de cobertura, mas nunca o ultimo requisito real.
candidatos_respeitando_isca(
    Target,
    Inventario,
    Disponiveis,
    Filtrados
) :-
    findall(Item,
        ( member(Item, Disponiveis),
          \+ item_completa_cadeia_real(
              Item,
              Target,
              Inventario
          )
        ),
        Filtrados0),
    sort(Filtrados0, Filtrados),
    Filtrados \= [].

item_avanca_cadeia_isca(Item, Target, Inventario) :-
    tesouro_mem(TesouroIsca, _, RequisitosIsca),
    TesouroIsca \== Target,
    requisito_recursivo(RequisitosIsca, Item),
    \+ requisitos_satisfeitos(RequisitosIsca, Inventario),
    !.

item_completa_cadeia_real(Item, Target, Inventario) :-
    tesouro_mem(Target, _, Requisitos),
    requisitos_satisfeitos(
        Requisitos,
        [Item | Inventario]
    ),
    \+ requisitos_satisfeitos(Requisitos, Inventario).

pontuar_candidatos([], _, _, _, []).
pontuar_candidatos(
    [Item | Resto],
    Cidade,
    Target,
    Inventario,
    [Pontuacao-Item | Pares]
) :-
    pontuar_candidato(Item, Cidade, Target, Inventario, Pontuacao),
    pontuar_candidatos(
        Resto,
        Cidade,
        Target,
        Inventario,
        Pares
    ).

pontuar_candidato(Item, Cidade, Target, Inventario, Pontuacao) :-
    InventarioDepois = [Item | Inventario],
    itens_disponiveis_cobertura(InventarioDepois, Depois),
    risco_continuacao_forcada(Item, Depois, RiscoForcado),
    quantidade_dependentes_diretos(Item, InventarioDepois, Dependentes),
    cidade_objeto(Item, CidadeItem),
    distancia(Cidade, CidadeItem, Distancia),
    item_na_cadeia_real(Item, Target, NaCadeiaReal),
    penalidade_conectividade_inicio(
        Inventario,
        CidadeItem,
        PenalidadeConectividade
    ),

    % Menor pontuacao e melhor.
    % Uma continuacao forcada recebe penalidade muito alta.
    % A conectividade e apenas um criterio suave do inicio da partida.
    Pontuacao is
        RiscoForcado * 10000 +
        NaCadeiaReal * 500 +
        Dependentes * 30 +
        PenalidadeConectividade +
        Distancia.

% Risco maximo: depois de roubar Item, sobra apenas um roubo possivel
% e esse unico roubo depende diretamente de Item.
risco_continuacao_forcada(Item, [Unico], 1) :-
    depende_diretamente(Unico, Item),
    !.
risco_continuacao_forcada(_, _, 0).

quantidade_dependentes_diretos(Item, Inventario, Quantidade) :-
    findall(Dependente,
        ( item_mem(Dependente, _, Requisitos),
          \+ memberchk(Dependente, Inventario),
          memberchk(Item, Requisitos)
        ),
        Dependentes0),
    sort(Dependentes0, Dependentes),
    length(Dependentes, Quantidade).

depende_diretamente(ItemDependente, Requisito) :-
    item_mem(ItemDependente, _, Requisitos),
    memberchk(Requisito, Requisitos).

item_na_cadeia_real(Item, Target, 1) :-
    tesouro_mem(Target, _, Requisitos),
    requisito_recursivo(Requisitos, Item),
    !.
item_na_cadeia_real(_, _, 0).

% ============================================================
% CONECTIVIDADE NO INICIO DA PARTIDA
% ============================================================

% Enquanto nenhuma cadeia de tesouro estiver claramente formada,
% cidades com conectividade extrema recebem uma penalidade suave:
% - grau muito baixo: risco de beco sem saida e previsibilidade;
% - grau muito alto: excesso de rotas obvias e pontos centrais.
%
% A penalidade desaparece assim que alguma cadeia de tesouro fica
% completa, pois nessa fase completar cobertura e evitar bloqueios
% passa a ser mais importante que a conectividade local.

penalidade_conectividade_inicio(Inventario, _, 0) :-
    alguma_cadeia_claramente_formada(Inventario),
    !.
penalidade_conectividade_inicio(_, Cidade, Penalidade) :-
    grau_cidade(Cidade, Grau),
    penalidade_por_grau(Grau, Penalidade).

alguma_cadeia_claramente_formada(Inventario) :-
    tesouro_mem(_, _, Requisitos),
    requisitos_satisfeitos(Requisitos, Inventario),
    !.

penalidade_por_grau(Grau, 120) :-
    grau_baixo_limite(Limite),
    Grau =< Limite,
    !.
penalidade_por_grau(Grau, 90) :-
    grau_alto_limite(Limite),
    Grau >= Limite,
    !.
penalidade_por_grau(_, 0).

grau_cidade(Cidade, Grau) :-
    findall(Vizinho, aresta(Cidade, Vizinho), Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    length(Vizinhos, Grau).

vizinho_comum_preferido(Cidade, Proxima) :-
    findall(Penalidade-Vizinho,
        ( aresta(Cidade, Vizinho),
          \+ tesouro_mem(_, Vizinho, _),
          grau_cidade(Vizinho, Grau),
          penalidade_por_grau(Grau, Penalidade)
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [Melhor-_ | _],
    findall(V,
            member(Melhor-V, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Proxima, Melhores),
    !.
vizinho_comum_preferido(Cidade, Proxima) :-
    findall(Vizinho, aresta(Cidade, Vizinho), Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    random_member(Proxima, Vizinhos).

% ============================================================
% ESCOLHA DO TESOURO ALVO
% ============================================================

% v7 NAO reserva itens: todos ficam coletaveis, pois a estrategia
% depende de completar cadeias de baits (reservas poderiam bloquear
% uma delas). Alvo = tesouro de cadeia real mais curta, preferindo os
% que deixam >= 2 outros tesouros resolviveis (ambiguidade viavel
% contra o marpled).
escolher_tesouro(Tesouro) :-
    findall(Prefere-Custo-T,
        ( tesouro_mem(T, _, Requisitos),
          cadeia_resolvivel(Requisitos),
          requisitos_totais(Requisitos, Cadeia),
          length(Cadeia, Custo),
          ( baits_possiveis(T, Max), Max >= 2
          -> Prefere = 0
          ;  Prefere = 1
          )
        ),
        Candidatos),
    Candidatos \= [],
    keysort(Candidatos, Ordenados),
    Ordenados = [MelhorPrefere-MenorCusto-_ | _],
    findall(T,
            member(MelhorPrefere-MenorCusto-T, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Tesouro, Melhores).

% ============================================================
% DISFARCE E IDENTIDADE
% ============================================================

escolher_identidade(Suspeitos, IdEscolhido) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuar_identidade(Aparencia, Suspeitos, Pontuacao)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, Descendentes),
    Descendentes = [MelhorPontuacao-_ | _],
    findall(Id,
            member(MelhorPontuacao-Id, Descendentes),
            Empatados0),
    sort(Empatados0, Empatados),
    random_member(IdEscolhido, Empatados).

pontuar_identidade(Aparencia, Suspeitos, Pontuacao) :-
    primeiros_n(3, Aparencia, Prefixo),
    pontuar_prefixos_identidade(
        Prefixo,
        Aparencia,
        Suspeitos,
        1,
        0,
        Pontuacao
    ).

pontuar_prefixos_identidade([], _, _, _, P, P).
pontuar_prefixos_identidade([_ | Resto], Aparencia, Suspeitos,
                            Tamanho, Acumulado, Pontuacao) :-
    primeiros_n(Tamanho, Aparencia, Observados),
    contar_suspeitos_compativeis(Observados, Suspeitos, Quantidade),
    peso_prefixo(Tamanho, Peso),
    Novo is Acumulado + Quantidade * Peso,
    Proximo is Tamanho + 1,
    pontuar_prefixos_identidade(
        Resto,
        Aparencia,
        Suspeitos,
        Proximo,
        Novo,
        Pontuacao
    ).

peso_prefixo(1, 100).
peso_prefixo(2, 30).
peso_prefixo(_, 10).

contar_suspeitos_compativeis(Observados, Suspeitos, Quantidade) :-
    findall(Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          atributos_compativeis(Observados, Aparencia)
        ),
        IDs),
    sort(IDs, Unicos),
    length(Unicos, Quantidade).

atributos_compativeis([], _).
atributos_compativeis([Atributo | Resto], Aparencia) :-
    memberchk(Atributo, Aparencia),
    atributos_compativeis(Resto, Aparencia).

escolher_tres_disfarces(IdReal, Aparencia, Modificacoes) :-
    primeiros_n(3, Aparencia, Primeiros),
    maplist(modificacao_disfarce(IdReal), Primeiros, Modificacoes).

modificacao_disfarce(IdReal, Original, trocar(Original, Falso)) :-
    findall(Alternativa,
        ( suspeito_mem(Suspeito),
          id_e_aparencia(Suspeito, OutroId, Atributos),
          OutroId \== IdReal,
          member(Alternativa, Atributos),
          mesmo_tipo(Original, Alternativa),
          Alternativa \== Original
        ),
        Alternativas0),
    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Falso, Alternativas),
    !.
modificacao_disfarce(_, Original, omitir(Original)).

mesmo_tipo(A, B) :-
    functor(A, Nome, Aridade),
    functor(B, Nome, Aridade).

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

% ============================================================
% DEPENDENCIAS
% ============================================================

cadeia_resolvivel(Requisitos) :-
    cadeia_resolvivel(Requisitos, []).

cadeia_resolvivel([], _).
cadeia_resolvivel([Item | Resto], Visitados) :-
    \+ memberchk(Item, Visitados),
    item_mem(Item, _, SubRequisitos),
    cadeia_resolvivel(SubRequisitos, [Item | Visitados]),
    cadeia_resolvivel(Resto, Visitados).

requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Item,
            requisito_recursivo(Requisitos, Item),
            Todos),
    sort(Todos, TodosUnicos).

requisito_recursivo(Requisitos, Item) :-
    member(Item, Requisitos).
requisito_recursivo(Requisitos, ItemIndireto) :-
    member(Item, Requisitos),
    item_mem(Item, _, SubRequisitos),
    requisito_recursivo(SubRequisitos, ItemIndireto).

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Item | Resto], Inventario) :-
    memberchk(Item, Inventario),
    requisitos_satisfeitos(Resto, Inventario).

cidade_objeto(Objeto, Cidade) :-
    item_mem(Objeto, Cidade, _),
    !.
cidade_objeto(Objeto, Cidade) :-
    tesouro_mem(Objeto, Cidade, _).

% ============================================================
% MOVIMENTO E ROTAS ANTI-OBVIAS
% ============================================================

% Fugindo com o alvo em maos: sai por um vizinho que nao seja a cidade
% trancada (a fuga precisa dar certo: vitoria = roubar o alvo E estar
% em outra cidade no turno seguinte).
adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, _),
    move(Cidade, Proxima)
) :-
    memberchk(Target, Itens),
    !,
    lock_evasao(Lock),
    saida_evasiva_lock(Cidade, Lock, Proxima),
    registrar_cidade_anterior(Cidade).

% Movimento normal (coleta ou aproximacao final): anda pelo caminho
% minimo ate o destino estrategico e so desvia se o passo canonico
% cairia justo na cidade trancada (lock ATIVO persistente). Evasao
% barata: nao recusa objetivos nem reformula rotas (isso paralisava e
% so fazia sentido se o oponente fosse mesmo o shortestd) — apenas
% nunca pisa voluntariamente no lock.
adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, _),
    move(Cidade, Proxima)
) :-
    destino_estrategico(Cidade, Target, Itens, Destino),
    Destino \== Cidade,
    !,
    passo_seguro(Cidade, Destino, Proxima),
    registrar_cidade_anterior(Cidade).

adaptar_movimento(_, Acao, Acao).

destino_estrategico(Cidade, Target, Itens, Destino) :-
    proximo_item_cobertura(Cidade, Target, Itens, Item),
    cidade_objeto(Item, Destino),
    !.
destino_estrategico(_Cidade, Target, Itens, Destino) :-
    pode_iniciar_aproximacao_final(Target, Itens),
    tesouro_mem(Target, Destino, _).

% Escolha do passo (SOFT, fail-safe):
%  1. evita a UNIAO de cidades perigosas rumo ao MESMO destino;
%  2. senao, passo minimo evitando as outras cidades de tesouro;
%  3. senao, o passo minimo canonico (aceita o risco).
% Nunca recusa o objetivo: se o proprio destino e perigoso, a etapa 1
% falha e cai nas seguintes (a paralisia so acontece se bloquearmos o
% destino, o que nao fazemos).
passo_seguro(Cidade, Destino, Proxima) :-
    passo_evitando_riscos(Cidade, Destino, Proxima),
    !.
passo_seguro(Cidade, Destino, Proxima) :-
    passo_min_base(Cidade, Destino, Proxima),
    !.
passo_seguro(Cidade, Destino, Proxima) :-
    proximo_passo(Cidade, Destino, Proxima).

% Caminho que contorna todas as cidades perigosas previstas (menos a
% origem), so se: o destino NAO for perigoso, houver rota, E o desvio
% custar no maximo `folga_desvio` passos a mais que o minimo. O teto e
% essencial: sem ele, num mapa apertado o desvio estoura o orcamento de
% turnos e paralisa (empate/derrota). Com ele, so desvia quando e
% barato; senao aceita o risco e vai pelo minimo.
passo_evitando_riscos(Cidade, Destino, Proxima) :-
    findall(Perigosa, cidade_a_evitar(Perigosa), Perigos0),
    sort(Perigos0, Perigos),
    Perigos \= [],
    delete(Perigos, Cidade, Bloqueados),
    \+ memberchk(Destino, Bloqueados),
    caminho_sem_cidades(Cidade, Destino, Bloqueados, [Cidade, Proxima | Resto]),
    distancia(Cidade, Destino, DMin),
    length([Proxima | Resto], DDesvio),
    folga_desvio(Folga),
    DDesvio =< DMin + Folga.

passo_min_base(Cidade, Destino, Proxima) :-
    cidades_tesouro_exceto_destino(Destino, Bloq0),
    delete(Bloq0, Cidade, Bloq),
    Bloq \= [],
    caminho_sem_cidades(Cidade, Destino, Bloq, [Cidade, Proxima | _]),
    !.
passo_min_base(Cidade, Destino, Proxima) :-
    proximo_passo(Cidade, Destino, Proxima).

% Passo minimo (mesmo custo ate Destino) que nao pisa no lock.
passo_minimo_evitando(Cidade, Destino, Lock, Proxima) :-
    distancia(Cidade, Destino, D),
    D > 0,
    DSeguinte is D - 1,
    findall(Vizinho,
        ( aresta(Cidade, Vizinho),
          Vizinho \== Lock,
          distancia(Vizinho, Destino, DSeguinte),
          nao_retorna(Vizinho)
        ),
        Alternativas0),
    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Proxima, Alternativas).

cidades_tesouro_exceto_destino(Destino, Bloqueadas) :-
    findall(Cidade,
        ( tesouro_mem(_, Cidade, _),
          Cidade \== Destino
        ),
        Bloqueadas0),
    sort(Bloqueadas0, Bloqueadas).

% Sai da celula que sera trancada neste turno: prefere um vizinho fora
% da uniao de perigos e que nao volta; senao qualquer vizinho (tem que
% sair de qualquer jeito antes do lock cair).
fuga_da_trava(Cidade, Proxima) :-
    findall(Perigosa, cidade_a_evitar(Perigosa), Perigos0),
    sort(Perigos0, Perigos),
    findall(Vizinho,
        ( aresta(Cidade, Vizinho),
          Vizinho \== Cidade,
          \+ memberchk(Vizinho, Perigos),
          nao_retorna(Vizinho)
        ),
        Vs0),
    sort(Vs0, Vs),
    Vs \= [],
    !,
    random_member(Proxima, Vs).
fuga_da_trava(Cidade, Proxima) :-
    findall(Vizinho, ( aresta(Cidade, Vizinho), Vizinho \== Cidade ), Vs0),
    sort(Vs0, Vs),
    Vs \= [],
    random_member(Proxima, Vs).

% Saida de fuga: vizinho que nao volta e nao e a cidade trancada.
saida_evasiva_lock(Cidade, Lock, Proxima) :-
    findall(Vizinho,
        ( aresta(Cidade, Vizinho),
          nao_retorna(Vizinho),
          Vizinho \== Lock
        ),
        SemRetorno0),
    sort(SemRetorno0, SemRetorno),
    SemRetorno \= [],
    random_member(Proxima, SemRetorno),
    !.
saida_evasiva_lock(Cidade, _Lock, Proxima) :-
    saida_aleatoria(Cidade, Proxima).

saida_aleatoria(Cidade, Proxima) :-
    findall(Vizinho,
        ( aresta(Cidade, Vizinho),
          nao_retorna(Vizinho)
        ),
        SemRetorno0),
    sort(SemRetorno0, SemRetorno),
    SemRetorno \= [],
    random_member(Proxima, SemRetorno),
    !.
saida_aleatoria(Cidade, Proxima) :-
    findall(Vizinho, aresta(Cidade, Vizinho), Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    random_member(Proxima, Vizinhos).

nao_retorna(Cidade) :-
    cidade_anterior(Anterior),
    !,
    Cidade \== Anterior.
nao_retorna(_).

registrar_cidade_anterior(Cidade) :-
    retractall(cidade_anterior(_)),
    assertz(cidade_anterior(Cidade)).

% ============================================================
% BFS
% ============================================================

proximo_passo(Origem, Destino, Proxima) :-
    caminho_minimo(Origem, Destino, [Origem, Proxima | _]).

caminho_minimo(Origem, Destino, Caminho) :-
    bfs([[Origem]], [Origem], Destino, Invertido),
    reverse(Invertido, Caminho).

bfs([[Destino | Resto] | _], _, Destino, [Destino | Resto]) :-
    !.
bfs([[Atual | Caminho] | Fila], Visitados, Destino, Resultado) :-
    findall(Vizinho,
        ( aresta(Atual, Vizinho),
          \+ memberchk(Vizinho, Visitados)
        ),
        Vizinhos0),
    sort(Vizinhos0, Vizinhos),
    findall([Vizinho, Atual | Caminho],
            member(Vizinho, Vizinhos),
            NovosCaminhos),
    append(Visitados, Vizinhos, NovosVisitados),
    append(Fila, NovosCaminhos, NovaFila),
    bfs(NovaFila, NovosVisitados, Destino, Resultado).

distancia(Origem, Destino, 0) :-
    Origem == Destino,
    !.
distancia(Origem, Destino, Distancia) :-
    caminho_minimo(Origem, Destino, Caminho),
    tamanho_rota(Caminho, Distancia).

caminho_sem_cidades(Origem, Destino, Bloqueados, Caminho) :-
    \+ memberchk(Origem, Bloqueados),
    \+ memberchk(Destino, Bloqueados),
    bfs_sem_cidades(
        [[Origem]],
        [Origem],
        Destino,
        Bloqueados,
        Invertido
    ),
    reverse(Invertido, Caminho).

bfs_sem_cidades(
    [[Destino | Resto] | _],
    _,
    Destino,
    _,
    [Destino | Resto]
) :-
    !.
bfs_sem_cidades(
    [[Atual | Caminho] | Fila],
    Visitados,
    Destino,
    Bloqueados,
    Resultado
) :-
    findall(Vizinho,
        ( aresta(Atual, Vizinho),
          \+ memberchk(Vizinho, Visitados),
          \+ memberchk(Vizinho, Bloqueados)
        ),
        Vizinhos0),
    sort(Vizinhos0, Ordenados),
    random_permutation(Ordenados, Vizinhos),
    findall([Vizinho, Atual | Caminho],
            member(Vizinho, Vizinhos),
            NovosCaminhos),
    append(Visitados, Vizinhos, NovosVisitados),
    append(Fila, NovosCaminhos, NovaFila),
    bfs_sem_cidades(
        NovaFila,
        NovosVisitados,
        Destino,
        Bloqueados,
        Resultado
    ).

tamanho_rota(Rota, Distancia) :-
    length(Rota, Quantidade),
    Distancia is max(0, Quantidade - 1).

% ============================================================
% UTILITARIOS
% ============================================================

lembrar_aresta(A, B) :-
    lembrar_aresta_direcionada(A, B),
    lembrar_aresta_direcionada(B, A).

lembrar_aresta_direcionada(A, B) :-
    aresta(A, B),
    !.
lembrar_aresta_direcionada(A, B) :-
    assertz(aresta(A, B)).

primeiros_n(N, Lista, Primeiros) :-
    N > 0,
    length(Lista, Tamanho),
    Quantidade is min(N, Tamanho),
    length(Primeiros, Quantidade),
    append(Primeiros, _, Lista),
    !.
primeiros_n(_, _, []).

limpar_memoria :-
    retractall(aresta(_, _)),
    retractall(item_mem(_, _, _)),
    retractall(tesouro_mem(_, _, _)),
    retractall(suspeito_mem(_)),

    retractall(disfarce_feito),
    retractall(itens_necessarios_mem(_)),
    retractall(cidade_anterior(_)),

    retractall(eventos_turno(_)),
    retractall(trava_turno(_)),
    retractall(trava_ativa(_)),
    retractall(fila_bloqueios(_)),
    retractall(bloqueio_persistente(_)),
    retractall(origem_roubo_recente(_)),
    retractall(cidade_ja_bloqueada(_)),
    retractall(ultimo_roubo_cidade(_)),
    retractall(sd_edge(_, _)),
    retractall(sd_item(_, _, _)),
    retractall(sd_treasure(_, _, _)),
    retractall(sd_lock(_)).

% ============================================================
% REPLICA FIEL DA PREDICAO DO shortestd (memoria sd_, travas espelhadas)
% Portada de agents/shortestd.pl via agents/evasort.pl; qualquer mudanca
% no shortestd real deve refletir aqui.
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