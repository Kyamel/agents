:- module(baitpromax, [
    ladrao_preload/7,
    ladrao_action/3
]).

% baitpromax mantém INTEGRALMENTE as estratégias do baittpro (disfarce forte,
% identidade segura, anti-marple e toda a lógica de isca do baitt) e adiciona
% DIVERSIFICAÇÃO DE OBJETIVO.
%
% Motivação (medida em replays): o detetive_crenca não prende o ladrão pela ROTA
% — ele TRANCA a CIDADE do próximo item (fechar(cidade_do_item)) e espera. O
% ladrão entra para roubar e é preso ao sair. Mudar o caminho até a cidade não
% adianta: a cidade é obrigatória. O que engana o detetive é ir para uma cidade
% DIFERENTE da que ele previu.
%
% E ele prevê assim (igual ao baitt): entre os pré-requisitos ainda pendentes do
% tesouro-alvo, assume que o ladrão busca SEMPRE o PRIMEIRO da lista
% (proximo_objetivo_real -> requisito_pendente pega o primeiro pendente). Como os
% pré-requisitos são independentes e podem ser coletados em qualquer ordem, o
% ladrão tem liberdade de escolher OUTRO pendente. Se esse outro estiver à mesma
% distância (ou mais perto — nunca mais longe, o orçamento de turnos é apertado),
% o ladrão desvia de graça e o detetive tranca a cidade errada.
%
% Duas peças, ambas só no modo "cadeia real" (não mexe em fuga nem em isca):
%   1. Redirecionar o deslocamento para a cidade de um objetivo pendente
%      alternativo, à mesma distância ou mais perto que o canônico.
%   2. Ao chegar nessa cidade, roubar o item pendente que está ali — mesmo que o
%      baittpro preferisse seguir para outro item (senão ele passaria direto).

:- use_module('baittpro.pl', []).


% --- Preload: delega tudo ao baittpro (que delega ao baitt)

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    baittpro:ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
                            LadraoID, ObjetivoLadrao).


% --- Ação
%
% Deixa o baittpro decidir. Só interferimos quando a decisão dele é um
% DESLOCAMENTO — e apenas se estivermos em modo "cadeia real" (não fuga, não
% isca). Aí redirecionamos o objetivo. Disfarce, roubo prioritário, isca,
% anti-marple e fuga passam intactos.

ladrao_action(Eventos, Estado, Acao) :-
    Estado = thief(loc(Cidade), _, _, Target, Itens, _),
    baittpro:ladrao_action(Eventos, Estado, AcaoBase),
    ( AcaoBase = move(Cidade, PassoCanonico),
      modo_cadeia_real(Cidade, Target, Itens)
    -> acao_cadeia_real(Cidade, Target, Itens, PassoCanonico, Acao)
    ;  Acao = AcaoBase
    ).


% Estamos perseguindo a cadeia real (baitt clausula 7) quando NÃO é fuga (não
% temos o tesouro) e NÃO há desvio de isca ativo (baitt clausula 5).
modo_cadeia_real(Cidade, Target, Itens) :-
    \+ member(Target, Itens),
    \+ cidade_isca_ativa(Cidade, Target, Itens, _).


% Em modo cadeia real, com o baittpro querendo se deslocar:
%
% (a) Se há um objetivo pendente ROUBÁVEL AQUI, rouba agora — cobre o caso de
%     termos desviado para a cidade deste item; sem isso o baittpro passaria
%     direto rumo ao item que ele prefere.
acao_cadeia_real(Cidade, Target, Itens, _PassoCanonico, roubar(Item)) :-
    objetivo_pendente(Target, Itens, Item),
    baitt:item_conhecido(Item, Cidade, Requisitos),
    baitt:requisitos_satisfeitos(Requisitos, Itens),
    !.
% (b) Redireciona rumo à cidade de um objetivo pendente alternativo (mesma
%     distância ou mais perto que o canônico).
acao_cadeia_real(Cidade, Target, Itens, _PassoCanonico, move(Cidade, Passo)) :-
    destino_diversificado(Cidade, Target, Itens, CidadeDiv),
    !,
    baitt:proximo_passo(Cidade, CidadeDiv, Passo).
% (c) Sem alternativa boa: segue o passo canônico do baittpro.
acao_cadeia_real(Cidade, _Target, _Itens, PassoCanonico, move(Cidade, PassoCanonico)).


% --- Escolha do destino diversificado
%
% Objetivo canônico = o que o baitt/detetive assumem (primeiro pendente).
% Alternativas = qualquer OUTRO objetivo pendente cuja cidade esteja à mesma
% distância ou mais perto. Preferimos o mais barato; empate desempata pelo maior,
% para forçar uma escolha que realmente diverge da previsão.
destino_diversificado(Cidade, Target, Itens, CidadeDiv) :-
    baitt:proximo_objetivo(Target, Itens, ObjCanonico),
    baitt:cidade_do_objeto(ObjCanonico, CidadeCanon),
    baitt:distancia_bfs(Cidade, CidadeCanon, DCanon),
    findall(DAlt-CidadeAlt,
        ( objetivo_pendente(Target, Itens, ObjAlt),
          ObjAlt \== ObjCanonico,
          baitt:cidade_do_objeto(ObjAlt, CidadeAlt),
          CidadeAlt \== CidadeCanon,
          baitt:distancia_bfs(Cidade, CidadeAlt, DAlt),
          DAlt =< DCanon
        ),
        Pares),
    Pares \== [],
    keysort(Pares, Ordenados),
    Ordenados = [MenorD-_ | _],
    findall(C, member(MenorD-C, Ordenados), Cidades),
    last(Cidades, CidadeDiv).


% Enumera os objetivos pendentes "roubáveis" da cadeia real: para cada
% pré-requisito ainda não coletado do tesouro-alvo, a folha atual da sua sub-
% cadeia (resolver_requisito desce até o item sem pendências). Pré-requisitos
% independentes geram folhas diferentes — o leque de escolha do ladrão.
objetivo_pendente(Target, Itens, Folha) :-
    baitt:tesouro_conhecido(Target, _, Requisitos),
    member(Req, Requisitos),
    Req \== Target,
    \+ member(Req, Itens),
    baitt:resolver_requisito(Req, Itens, Folha).


% Reproduz a guarda da clausula 5 do baitt (desvio de isca ativo). Devolve a
% cidade da isca escolhida quando aplicável.
cidade_isca_ativa(Cidade, Target, Itens, CidadeIsca) :-
    baitt:itens_isca(ItensIsca),
    \+ baitt:prereqs_reais_prontos(Target, Itens),
    member(ItemIsca, ItensIsca),
    \+ member(ItemIsca, Itens),
    \+ baitt:item_do_objetivo(ItemIsca, Target),
    baitt:item_conhecido(ItemIsca, CidadeIsca, ReqIsca),
    baitt:requisitos_satisfeitos(ReqIsca, Itens),
    baitt:proximo_objetivo(Target, Itens, ObjetivoReal),
    baitt:cidade_do_objeto(ObjetivoReal, CidadeReal),
    baitt:distancia_bfs(Cidade, CidadeIsca, D1),
    baitt:distancia_bfs(CidadeIsca, CidadeReal, D2),
    baitt:distancia_bfs(Cidade, CidadeReal, DDireto),
    D1 + D2 - DDireto =< 2,
    !.
