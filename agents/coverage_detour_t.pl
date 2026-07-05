% ============================================================
% LADRAO: coverage_detour_t
%
% Ladrao de cobertura com desvios anti-predicao. Coleta ampla (deixando
% poucos itens de fora) para ocultar o alvo, e adiciona uma camada forte
% de imprevisibilidade de rota: penaliza cidades de conectividade extrema
% no inicio, evita passar por cidades de tesouros ja completos e, depois
% de cada roubo, planeja desvios que fogem do caminho minimo previsivel.
% So rouba o alvo quando a cobertura esta pronta. Muito dificil de prever,
% mas as varias camadas de desvio custam turnos e podem levar ao empate
% em mapas grandes.
% ============================================================

:- module(coverage_detour_t, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- dynamic aresta/2.
:- dynamic item_mem/3.
:- dynamic tesouro_mem/3.
:- dynamic suspeito_mem/1.

:- dynamic disfarce_feito/0.
:- dynamic itens_reservados/1.
:- dynamic inventario_anterior/1.
:- dynamic ultimo_item_roubado/1.
:- dynamic rota_alternativa/2.
:- dynamic cidade_anterior/1.
:- dynamic desvio_final/1.
:- dynamic desvio_final_concluido/0.

folga_desvio(2).

% Faixa de conectividade preferida no inicio da partida.
% Graus abaixo ou acima disso recebem apenas penalidade, nunca bloqueio.
grau_baixo_limite(1).
grau_alto_limite(5).

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

    escolher_identidade(Suspeitos, LadraoID),
    escolher_tesouro_e_reservas(Objetivo, Reservados),
    assertz(itens_reservados(Reservados)),

    assertz(inventario_anterior([])),
    assertz(rota_alternativa(nenhum, [])).

% ============================================================
% ACAO PRINCIPAL
% ============================================================

ladrao_action(_Eventos, Estado, AcaoFinal) :-
    preparar_turno(Estado),
    decidir_acao(Estado, AcaoInicial),
    adaptar_movimento(Estado, AcaoInicial, AcaoFinal),
    !.
ladrao_action(_, _, nada).

% ============================================================
% MEMORIA DO ULTIMO ROUBO
% ============================================================

preparar_turno(thief(loc(Cidade), _, _, Target, Itens, _)) :-
    inventario_anterior(Anteriores),
    detectar_novo_item(Itens, Anteriores, NovoItem),
    atualizar_memoria_roubo(NovoItem, Cidade, Target, Itens),
    retractall(inventario_anterior(_)),
    assertz(inventario_anterior(Itens)),
    !.
preparar_turno(_).

detectar_novo_item(Itens, Anteriores, NovoItem) :-
    subtract(Itens, Anteriores, Novos),
    Novos = [NovoItem | _],
    !.
detectar_novo_item(_, _, nenhum).

atualizar_memoria_roubo(nenhum, _, _, _) :-
    !.
atualizar_memoria_roubo(Item, Cidade, Target, Itens) :-
    retractall(ultimo_item_roubado(_)),
    assertz(ultimo_item_roubado(Item)),
    planejar_rota_apos_roubo(Cidade, Target, Itens).

% ============================================================
% DECISAO
% ============================================================

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

% Quando a cobertura global esta pronta, nao parte diretamente para
% o alvo se ele for o tesouro completo mais proximo. Nesse caso, visita
% primeiro a cidade de outro tesouro completo e so depois retorna ao alvo.
decidir_acao(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, Proxima)
) :-
    pode_iniciar_aproximacao_final(Target, Itens),
    destino_final_seguro(Cidade, Target, Itens, Destino),
    Cidade \== Destino,
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
% COBERTURA GLOBAL
% ============================================================

todos_itens(Itens) :-
    findall(Item, item_mem(Item, _, _), Itens0),
    sort(Itens0, Itens).

itens_a_coletar(ItensColetar) :-
    todos_itens(Todos),
    itens_reservados(Reservados),
    subtract(Todos, Reservados, ItensColetar).

cobertura_global_pronta(Inventario) :-
    itens_a_coletar(ItensColetar),
    forall(member(Item, ItensColetar),
           memberchk(Item, Inventario)).

% A aproximacao final so pode comecar quando:
% - toda a cobertura global planejada estiver pronta;
% - pelo menos uma cadeia de outro tesouro ja estiver completa;
% - todos os requisitos do alvo real estiverem completos.
%
% Como o ultimo item da isca foi roubado em um turno anterior, seu
% evento ja foi liberado ao detetive antes de o ultimo requisito real
% ser roubado no turno seguinte.
pode_roubar_tesouro_final(Target, Cidade, Inventario) :-
    cobertura_global_pronta(Inventario),
    existe_cadeia_isca_completa(Target, Inventario),
    tesouro_mem(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Inventario).

pode_iniciar_aproximacao_final(Target, Inventario) :-
    cobertura_global_pronta(Inventario),
    existe_cadeia_isca_completa(Target, Inventario),
    tesouro_mem(Target, _, Requisitos),
    requisitos_satisfeitos(Requisitos, Inventario).


% ============================================================
% ESCOLHA SEGURA DO TESOURO FINAL
% ============================================================

% O desvio final nunca usa uma cidade que contenha tesouro.
% Depois que a cobertura global fica pronta, todas as cidades de
% tesouro sao tratadas como bloqueadas, exceto a cidade do alvo real.

% Continua um desvio ja iniciado ate um ponto comum do mapa.
destino_final_seguro(Cidade, _, _, Destino) :-
    desvio_final(Destino),
    Cidade \== Destino,
    !.

% Ao chegar ao ponto de desvio, marca a contramedida como concluida.
destino_final_seguro(Cidade, Target, _, Destino) :-
    desvio_final(Cidade),
    !,
    retractall(desvio_final(_)),
    ( desvio_final_concluido -> true
    ; assertz(desvio_final_concluido)
    ),
    tesouro_mem(Target, Destino, _).

% Se o alvo real for o tesouro completo mais proximo, faz primeiro
% um desvio para uma cidade comum, nunca para outra cidade de tesouro.
destino_final_seguro(Cidade, Target, Itens, Destino) :-
    \+ desvio_final_concluido,
    alvo_eh_tesouro_mais_proximo(Cidade, Target, Itens),
    escolher_ponto_desvio_sem_tesouro(Cidade, Target, Destino),
    retractall(desvio_final(_)),
    assertz(desvio_final(Destino)),
    !.

% Depois do desvio, ou quando ele nao for necessario, segue ao alvo.
destino_final_seguro(_, Target, _, Destino) :-
    tesouro_mem(Target, Destino, _).

% O alvo e o mais proximo quando nenhum outro tesouro completo esta
% estritamente mais perto da posicao atual.
alvo_eh_tesouro_mais_proximo(Cidade, Target, Itens) :-
    tesouro_mem(Target, CidadeTarget, RequisitosTarget),
    requisitos_satisfeitos(RequisitosTarget, Itens),
    distancia(Cidade, CidadeTarget, DistanciaTarget),
    \+ (
        tesouro_completo_diferente(
            Target,
            Itens,
            _,
            OutraCidade
        ),
        distancia(Cidade, OutraCidade, OutraDistancia),
        OutraDistancia < DistanciaTarget
    ).

tesouro_completo_diferente(Target, Itens, Tesouro, Cidade) :-
    tesouro_mem(Tesouro, Cidade, Requisitos),
    Tesouro \== Target,
    requisitos_satisfeitos(Requisitos, Itens).

% Escolhe um ponto comum do mapa que:
% - nao contenha tesouro;
% - seja alcancavel sem atravessar cidades de tesouro;
% - nao seja a cidade atual;
% - aumente, quando possivel, a distancia ate o alvo verdadeiro.
escolher_ponto_desvio_sem_tesouro(Cidade, Target, Destino) :-
    tesouro_mem(Target, CidadeTarget, _),
    cidades_tesouro_exceto(Target, Bloqueadas),
    distancia(Cidade, CidadeTarget, DistanciaAtual),
    findall(NegDistancia-Candidata,
        ( cidade_comum(Candidata),
          Candidata \== Cidade,
          caminho_sem_cidades(
              Cidade,
              Candidata,
              Bloqueadas,
              _
          ),
          distancia(Candidata, CidadeTarget, DistanciaAlvo),
          DistanciaAlvo > DistanciaAtual,
          NegDistancia is -DistanciaAlvo
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [Melhor-_ | _],
    findall(C,
            member(Melhor-C, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Destino, Melhores),
    !.

% Fallback: qualquer cidade comum alcancavel sem passar por tesouros.
escolher_ponto_desvio_sem_tesouro(Cidade, Target, Destino) :-
    cidades_tesouro_exceto(Target, Bloqueadas),
    findall(Candidata,
        ( cidade_comum(Candidata),
          Candidata \== Cidade,
          caminho_sem_cidades(
              Cidade,
              Candidata,
              Bloqueadas,
              _
          )
        ),
        Candidatas0),
    sort(Candidatas0, Candidatas),
    Candidatas \= [],
    random_member(Destino, Candidatas).

cidade_comum(Cidade) :-
    aresta(Cidade, _),
    \+ tesouro_mem(_, Cidade, _).

cidades_tesouro_exceto(Target, Bloqueadas) :-
    tesouro_mem(Target, CidadeTarget, _),
    findall(Cidade,
        ( tesouro_mem(_, Cidade, _),
          Cidade \== CidadeTarget
        ),
        Bloqueadas0),
    sort(Bloqueadas0, Bloqueadas).

% Calcula o proximo passo da fase final sem atravessar nenhuma cidade
% de tesouro que nao seja o destino verdadeiro.
passo_final_sem_tesouros(Cidade, Target, Destino, Proxima) :-
    cidades_tesouro_exceto(Target, Bloqueadas0),
    delete(Bloqueadas0, Cidade, Bloqueadas),
    caminho_sem_cidades(
        Cidade,
        Destino,
        Bloqueadas,
        [Cidade, Proxima | _]
    ),
    !.

% So usa o caminho normal se nao existir qualquer rota que evite as
% outras cidades de tesouro. Esse fallback impede o agente de travar
% em mapas cujo grafo obrigue a passagem por uma delas.
passo_final_sem_tesouros(Cidade, _, Destino, Proxima) :-
    proximo_passo(Cidade, Destino, Proxima).

% Seleciona entre todos os itens atualmente roubaveis e nao reservados.
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
    itens_reservados(Reservados),
    findall(Item,
        ( item_mem(Item, _, Requisitos),
          \+ memberchk(Item, Inventario),
          \+ memberchk(Item, Reservados),
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
    existe_cadeia_isca_completa(Target, Inventario),
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

existe_cadeia_isca_completa(Target, Inventario) :-
    tesouro_mem(Tesouro, _, Requisitos),
    Tesouro \== Target,
    requisitos_satisfeitos(Requisitos, Inventario),
    !.

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
% ESCOLHA DO TESOURO E DOS DOIS ITENS RESERVADOS
% ============================================================

% Prefere tesouros de cadeia curta, mas apenas quando existirem pelo
% menos dois itens fora de sua cadeia. Esses dois itens ficam sem ser
% roubados para esconder a estrategia de "coletar tudo".
escolher_tesouro_e_reservas(Tesouro, Reservados) :-
    findall(Custo-T-CandidatosReserva,
        candidato_tesouro(T, Custo, CandidatosReserva),
        Candidatos),
    Candidatos \= [],
    keysort(Candidatos, Ordenados),
    Ordenados = [MenorCusto-_-_ | _],
    findall(T-Cands,
            member(MenorCusto-T-Cands, Ordenados),
            Melhores0),
    random_member(Tesouro-CandidatosReserva, Melhores0),
    escolher_duas_reservas(Tesouro, CandidatosReserva, Reservados),
    !.

% Fallback: se nenhum tesouro permitir duas reservas externas,
% escolhe o menor e reserva quantos itens externos forem possiveis.
escolher_tesouro_e_reservas(Tesouro, Reservados) :-
    findall(Custo-T-CandidatosReserva,
        candidato_tesouro_fallback(T, Custo, CandidatosReserva),
        Candidatos),
    keysort(Candidatos, Ordenados),
    Ordenados = [MenorCusto-_-_ | _],
    findall(T-Cands,
            member(MenorCusto-T-Cands, Ordenados),
            Melhores0),
    random_member(Tesouro-CandidatosReserva, Melhores0),
    escolher_ate_duas_reservas(Tesouro, CandidatosReserva, Reservados).

candidato_tesouro(Tesouro, Custo, CandidatosReserva) :-
    tesouro_mem(Tesouro, _, Requisitos),
    cadeia_resolvivel(Requisitos),
    requisitos_totais(Requisitos, Cadeia),
    length(Cadeia, Custo),
    todos_itens(Todos),
    subtract(Todos, Cadeia, CandidatosReserva),
    length(CandidatosReserva, Quantidade),
    Quantidade >= 2.

candidato_tesouro_fallback(Tesouro, Custo, CandidatosReserva) :-
    tesouro_mem(Tesouro, _, Requisitos),
    cadeia_resolvivel(Requisitos),
    requisitos_totais(Requisitos, Cadeia),
    length(Cadeia, Custo),
    todos_itens(Todos),
    subtract(Todos, Cadeia, CandidatosReserva).

% Prefere reservar folhas ou itens pouco conectados, mas somente
% pares que ainda permitam completar pelo menos uma cadeia-isca.
escolher_duas_reservas(Target, Candidatos, Reservados) :-
    findall(Pontuacao-[A, B],
        ( selecionar_par_distinto(Candidatos, A, B),
          reservas_preservam_isca(Target, [A, B]),
          quantidade_dependentes_totais(A, PA),
          quantidade_dependentes_totais(B, PB),
          Pontuacao is PA + PB
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [Melhor-_ | _],
    findall(R,
            member(Melhor-R, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Reservados, Melhores),
    !.
escolher_duas_reservas(_, Candidatos, Reservados) :-
    pontuar_reservas(Candidatos, Pares),
    keysort(Pares, Ordenados),
    pares_para_itens(Ordenados, OrdenadosItens),
    primeiros_n(2, OrdenadosItens, Reservados).

escolher_ate_duas_reservas(Target, Candidatos, Reservados) :-
    escolher_duas_reservas(Target, Candidatos, Reservados),
    !.
escolher_ate_duas_reservas(Target, [Item | _], [Item]) :-
    reservas_preservam_isca(Target, [Item]),
    !.
escolher_ate_duas_reservas(_, Candidatos, Reservados) :-
    pontuar_reservas(Candidatos, Pares),
    keysort(Pares, Ordenados),
    pares_para_itens(Ordenados, OrdenadosItens),
    primeiros_n(2, OrdenadosItens, Reservados).

selecionar_par_distinto(Candidatos, A, B) :-
    select(A, Candidatos, Resto),
    member(B, Resto),
    A @< B.

reservas_preservam_isca(Target, Reservados) :-
    tesouro_mem(TesouroIsca, _, Requisitos),
    TesouroIsca \== Target,
    requisitos_totais(Requisitos, CadeiaIsca),
    nenhum_item_reservado_na_cadeia(
        Reservados,
        CadeiaIsca
    ),
    !.

nenhum_item_reservado_na_cadeia([], _).
nenhum_item_reservado_na_cadeia([Item | Resto], Cadeia) :-
    \+ memberchk(Item, Cadeia),
    nenhum_item_reservado_na_cadeia(Resto, Cadeia).

pontuar_reservas([], []).
pontuar_reservas([Item | Resto], [Pontuacao-Item | Pares]) :-
    quantidade_dependentes_totais(Item, Quantidade),
    Pontuacao is Quantidade,
    pontuar_reservas(Resto, Pares).

quantidade_dependentes_totais(Item, Quantidade) :-
    findall(Dependente,
        ( item_mem(Dependente, _, Requisitos),
          memberchk(Item, Requisitos)
        ),
        Dependentes0),
    sort(Dependentes0, Dependentes),
    length(Dependentes, Quantidade).

pares_para_itens([], []).
pares_para_itens([_-Item | Resto], [Item | Itens]) :-
    pares_para_itens(Resto, Itens).

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

adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, _),
    move(Cidade, Proxima)
) :-
    memberchk(Target, Itens),
    !,
    saida_aleatoria(Cidade, Proxima),
    registrar_cidade_anterior(Cidade).

% Na fase final, evita completamente cidades com tesouro que nao sejam
% a cidade do alvo verdadeiro.
adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, _),
    move(Cidade, Proxima)
) :-
    pode_iniciar_aproximacao_final(Target, Itens),
    \+ memberchk(Target, Itens),
    destino_final_seguro(Cidade, Target, Itens, Destino),
    Cidade \== Destino,
    passo_final_sem_tesouros(
        Cidade,
        Target,
        Destino,
        Proxima
    ),
    registrar_cidade_anterior(Cidade),
    !.

adaptar_movimento(
    thief(loc(Cidade), _, _, Target, Itens, _),
    move(Cidade, PassoPadrao),
    move(Cidade, Proxima)
) :-
    destino_estrategico(Cidade, Target, Itens, Destino),
    !,
    escolher_passo(Cidade, Destino, PassoPadrao, Proxima),
    registrar_cidade_anterior(Cidade).

adaptar_movimento(_, Acao, Acao).

destino_estrategico(Cidade, Target, Itens, Destino) :-
    proximo_item_cobertura(Cidade, Target, Itens, Item),
    cidade_objeto(Item, Destino),
    !.
destino_estrategico(Cidade, Target, Itens, Destino) :-
    pode_iniciar_aproximacao_final(Target, Itens),
    destino_final_seguro(Cidade, Target, Itens, Destino).

% Em qualquer fase intermediaria, cidades de tesouros cujas cadeias
% ja estao completas sao evitadas como passagem. A cidade continua
% permitida quando ela propria e o destino necessario.
escolher_passo(Cidade, Destino, _, Proxima) :-
    inventario_anterior(Inventario),
    passo_evitando_tesouros_prontos(
        Cidade,
        Destino,
        Inventario,
        Proxima
    ),
    !.
escolher_passo(Cidade, Destino, _, Proxima) :-
    consumir_rota_alternativa(Cidade, Destino, Proxima),
    !.
escolher_passo(Cidade, Destino, PassoPadrao, Proxima) :-
    passo_preferindo_conectividade_media(
        Cidade,
        Destino,
        PassoPadrao,
        Proxima
    ),
    !.
escolher_passo(Cidade, Destino, PassoPadrao, Proxima) :-
    passo_minimo_alternativo(Cidade, Destino, PassoPadrao, Proxima),
    !.
escolher_passo(_, _, PassoPadrao, PassoPadrao).

passo_evitando_tesouros_prontos(
    Cidade,
    Destino,
    Inventario,
    Proxima
) :-
    cidades_tesouros_prontos(
        Inventario,
        Destino,
        Bloqueadas0
    ),
    delete(Bloqueadas0, Cidade, Bloqueadas),
    Bloqueadas \= [],
    caminho_sem_cidades(
        Cidade,
        Destino,
        Bloqueadas,
        [Cidade, Proxima | _]
    ).

cidades_tesouros_prontos(Inventario, Destino, Bloqueadas) :-
    findall(CidadeTesouro,
        ( tesouro_mem(_, CidadeTesouro, Requisitos),
          CidadeTesouro \== Destino,
          requisitos_satisfeitos(
              Requisitos,
              Inventario
          )
        ),
        Bloqueadas0),
    sort(Bloqueadas0, Bloqueadas).

% No inicio, entre passos igualmente curtos, prefere cidades de grau
% intermediario. Nao bloqueia graus extremos: se forem necessarios,
% os fallbacks abaixo continuam permitindo a passagem.
passo_preferindo_conectividade_media(
    Cidade,
    Destino,
    PassoPadrao,
    Proxima
) :-
    inventario_anterior(Inventario),
    \+ alguma_cadeia_claramente_formada(Inventario),
    distancia(Cidade, Destino, DistanciaAtual),
    DistanciaSeguinte is DistanciaAtual - 1,
    findall(Penalidade-Vizinho,
        ( aresta(Cidade, Vizinho),
          distancia(Vizinho, Destino, DistanciaSeguinte),
          Vizinho \== PassoPadrao,
          nao_retorna(Vizinho),
          penalidade_conectividade_inicio(
              Inventario,
              Vizinho,
              Penalidade
          )
        ),
        Pares),
    Pares \= [],
    keysort(Pares, Ordenados),
    Ordenados = [MelhorPenalidade-_ | _],
    findall(V,
            member(MelhorPenalidade-V, Ordenados),
            Melhores0),
    sort(Melhores0, Melhores),
    random_member(Proxima, Melhores).

passo_minimo_alternativo(Cidade, Destino, PassoPadrao, Proxima) :-
    distancia(Cidade, Destino, D),
    DSeguinte is D - 1,
    findall(Vizinho,
        ( aresta(Cidade, Vizinho),
          distancia(Vizinho, Destino, DSeguinte),
          Vizinho \== PassoPadrao,
          nao_retorna(Vizinho)
        ),
        Alternativas0),
    sort(Alternativas0, Alternativas),
    Alternativas \= [],
    random_member(Proxima, Alternativas).

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

% Depois de cada roubo, calcula o proximo destino e tenta uma rota que
% bloqueie os primeiros vertices internos do caminho minimo.
planejar_rota_apos_roubo(_, Target, Itens) :-
    memberchk(Target, Itens),
    !,
    limpar_rota_alternativa.
planejar_rota_apos_roubo(Cidade, Target, Itens) :-
    destino_estrategico(Cidade, Target, Itens, Destino),
    Cidade \== Destino,
    caminho_minimo(Cidade, Destino, RotaMinima),
    vertices_internos(RotaMinima, Internos),
    tentar_desvio(Cidade, Destino, RotaMinima, Internos, Rota),
    salvar_rota_alternativa(Destino, Rota),
    !.
planejar_rota_apos_roubo(_, _, _) :-
    limpar_rota_alternativa.

vertices_internos([_Origem | Resto], Internos) :-
    append(Internos, [_Destino], Resto),
    !.
vertices_internos(_, []).

tentar_desvio(Origem, Destino, RotaMinima, Internos, Rota) :-
    primeiros_n(2, Internos, Bloqueados),
    Bloqueados \= [],
    rota_com_desvio_valido(
        Origem, Destino, RotaMinima, Bloqueados, Rota
    ),
    !.
tentar_desvio(Origem, Destino, RotaMinima, Internos, Rota) :-
    primeiros_n(1, Internos, Bloqueados),
    Bloqueados \= [],
    rota_com_desvio_valido(
        Origem, Destino, RotaMinima, Bloqueados, Rota
    ).

rota_com_desvio_valido(Origem, Destino, RotaMinima, Bloqueados, Rota) :-
    caminho_sem_cidades(Origem, Destino, Bloqueados, Rota),
    Rota \= RotaMinima,
    tamanho_rota(RotaMinima, Minimo),
    tamanho_rota(Rota, Alternativo),
    folga_desvio(Folga),
    Alternativo =< Minimo + Folga.

salvar_rota_alternativa(Destino, [_Origem | Passos]) :-
    Passos \= [],
    retractall(rota_alternativa(_, _)),
    assertz(rota_alternativa(Destino, Passos)).

limpar_rota_alternativa :-
    retractall(rota_alternativa(_, _)),
    assertz(rota_alternativa(nenhum, [])).

consumir_rota_alternativa(Cidade, Destino, Proxima) :-
    rota_alternativa(Destino, [Proxima | Resto]),
    aresta(Cidade, Proxima),
    retractall(rota_alternativa(_, _)),
    assertz(rota_alternativa(Destino, Resto)),
    !.

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
    retractall(itens_reservados(_)),
    retractall(inventario_anterior(_)),
    retractall(ultimo_item_roubado(_)),
    retractall(rota_alternativa(_, _)),
    retractall(cidade_anterior(_)),
    retractall(desvio_final(_)).
