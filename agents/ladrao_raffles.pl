% ============================================================
% Nome: Mayker Anselmo Brito Lellis     Matrícula: 22.2.8008 
% Nome: Lucas dos Anjos Camelo          Matrícula: 22.2.8002
% ============================================================

% ============================================================
% AGENTE LADRAO: ladrao_raffles
%
% Estrategias empregadas:
%
% 1. TESOURO: menor cadeia de pre-requisitos recursivos.
%
% 2. IDENTIDADE: suspeito com maior ambiguidade de aparencia,
%    dificultando o mandato do detetive.
%
% 3. DISFARCE INICIAL: modifica um atributo da aparencia usando
%    valor de outro suspeito antes do primeiro roubo, aumentando
%    a ambiguidade das primeiras pistas reveladas.
%
% 4. DISFARCE FORTE: plano pre-calculado que substitui atributos
%    chave por valores de outro suspeito, fazendo o ladrao parecer
%    uma identidade completamente diferente.
%
% 5. ISCA: rouba itens de tesouro secundario quando o desvio de
%    rota e pequeno, confundindo o detetive sobre o objetivo real.
%
% 6. DIVERSIFICACAO DE ROTA: quando ha itens pendentes a distancia
%    equivalente ao item canonico, escolhe um alternativo, evitando
%    que o detetive antecipe e bloqueie a proxima cidade obrigatoria.
%
% 7. CONTRA-MEDIDA ESPECIFICA: para cenarios com item critico de
%    bloqueio, prioriza sua coleta antes dos demais itens da cadeia,
%    neutralizando estrategias de fechamento antecipado.
%
% Prioridade: disfarce forte > fuga > disfarce inicial
%             > tesouro > isca > cadeia real (com diversificacao)
%             * contra-medida intercepta a sequência de itens do objetivo principal quando aplicavel
% ============================================================


:- module(ladrao_raffles, [
    ladrao_preload/7,
    ladrao_action/3
]).


:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.
:- dynamic tesouro_isca/1.
:- dynamic itens_isca/1.
:- dynamic disfarce_inicial_feito/0.
:- dynamic disfarces_usados/1.
:- dynamic plano_disfarce_forte/1.
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
    escolher_identidade(Suspeitos, IdOriginal),
    escolher_tesouro(ObjetivoOriginal),
    assertz(objetivo_atual(ObjetivoOriginal)),
    assertz(disfarces_usados(0)),
    escolher_isca(ObjetivoOriginal),
    escolher_identidade_segura(Suspeitos, IdOriginal, LadraoID, PlanoDisfarce),
    assertz(plano_disfarce_forte(PlanoDisfarce)),
    configurar_anti_marple(ObjetivoLadrao).

% ============================================================
% AÇÃO (wrapper de diversificação de objetivo)
% ============================================================
%
% Deixa acao_base decidir. Só interferimos quando a decisão é um DESLOCAMENTO e
% estamos em modo "cadeia real" (não fuga, não isca). Aí redirecionamos o
% objetivo. Disfarce, roubo prioritário, isca, e fuga passam intactos.

ladrao_action(Eventos, Estado, Acao) :-
    Estado = thief(loc(Cidade), _, _, Target, Itens, _),
    acao_base(Eventos, Estado, AcaoBase),
    ( AcaoBase = move(Cidade, PassoCanonico),
      modo_cadeia_real(Cidade, Target, Itens)
    -> acao_cadeia_real(Cidade, Target, Itens, PassoCanonico, Acao)
    ;  Acao = AcaoBase
    ).

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
% BASE DE DECISÃO — ordem de prioridade
% ============================================================

% Disfarce forte inicial
acao_base(_, thief(_, _, _, _, Itens, Dsg),
          disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_forte_feito,
    plano_disfarce_forte(Modificacoes),
    Modificacoes \= [],
    length(Modificacoes, Quantidade),
    Quantidade =< Dsg,
    marcar_disfarce_feito,
    !.

acao_base(_, thief(loc(whitechapel), _, _, obra_de_arte, Itens, _),
          roubar(codigo_alarme)) :-
    \+ memberchk(codigo_alarme, Itens),
    memberchk(radio_policial, Itens),
    !.
acao_base(_, thief(loc(Cidade), _, _, obra_de_arte, Itens, _),
          move(Cidade, Proxima)) :-
    \+ memberchk(codigo_alarme, Itens),
    memberchk(radio_policial, Itens),
    Cidade \= whitechapel,
    proximo_passo(Cidade, whitechapel, Proxima),
    !.

%  Fuga
acao_base(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, Vizinho)) :-
    member(Target, Itens),
    !,
    aresta_conhecida(Cidade, Vizinho).

% Disfarce inicial
acao_base(_, thief(loc(_), _, aparencia(AS), _Target, Itens, Dsg),
          disfarce([Modificacao])) :-
    Itens = [],
    \+ disfarce_inicial_feito,
    Dsg > 0,
    disfarces_usados(0),
    escolher_disfarce_final(AS, Modificacao),
    Modificacao \= none,
    !,
    assertz(disfarce_inicial_feito),
    retract(disfarces_usados(_)),
    assertz(disfarces_usados(1)).

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
% ESCOLHA DE ISCA
% ============================================================

escolher_isca(Target) :-
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
escolher_isca(_) :-
    assertz(tesouro_isca(nenhum)),
    assertz(itens_isca([])).

prereqs_reais_prontos(Target, Itens) :-
    tesouro_conhecido(Target, _, Reqs),
    subtract(Reqs, [Target], Prereqs),
    forall(member(P, Prereqs), member(P, Itens)).

% ============================================================
% DISFARCE 
% ============================================================

escolher_disfarce_final(AS, trocar(Original, Falso)) :-
    findall(A, (member(A, AS), A \= disfarce(_,_)), Reais),
    Reais \= [],
    last(Reais, Original),
    Original =.. [Functor, ValorAtual],
    valor_de_outro_suspeito(Functor, ValorAtual, ValorFalso),
    Falso =.. [Functor, ValorFalso],
    !.
escolher_disfarce_final(AS, omitir(Original)) :-
    findall(A, (member(A, AS), A \= disfarce(_,_)), Reais),
    Reais \= [],
    last(Reais, Original),
    !.

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

escolher_identidade_segura(Suspeitos, _IdOriginal, 9, Plano) :-
    aparencia_suspeito(9, Suspeitos,
        [A1, A2, OlhosReais, CabeloReal, UltimoReal]),
    aparencia_suspeito(1, Suspeitos,
        [A1, A2, OlhosFalsos, CabeloFalso | _]),
    Plano = [
        trocar(OlhosReais, OlhosFalsos),
        trocar(CabeloReal, CabeloFalso),
        omitir(UltimoReal)
    ],
    !.
escolher_identidade_segura(_Suspeitos, IdOriginal, IdOriginal, []).

marcar_disfarce_feito :-
    assertz(disfarce_forte_feito),
    retractall(disfarce_inicial_feito),
    assertz(disfarce_inicial_feito),
    retractall(disfarces_usados(_)),
    assertz(disfarces_usados(3)).

configurar_anti_marple(obra_de_arte) :-
    tesouro_conhecido(obra_de_arte, _, _),
    item_conhecido(codigo_alarme, _, _),
    !,
    retractall(objetivo_atual(_)),
    assertz(objetivo_atual(obra_de_arte)),
    retractall(tesouro_isca(_)),
    assertz(tesouro_isca(ouro_do_banco)),
    retractall(itens_isca(_)),
    assertz(itens_isca([codigo_alarme])).
configurar_anti_marple(Objetivo) :-
    objetivo_atual(Objetivo).

limpar_memoria_local :-
    retractall(plano_disfarce_forte(_)),
    retractall(disfarce_forte_feito).

% ============================================================
% MEMÓRIA
% ============================================================

limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)),
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