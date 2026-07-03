:- module(baittpro, [
    ladrao_preload/7,
    ladrao_action/3
]).

% Reutiliza a estratégia completa do baitt sem importar seus predicados
% exportados, pois este módulo oferece a mesma interface para a engine.
:- use_module('baitt.pl', []).

:- dynamic plano_disfarce_forte/1.
:- dynamic disfarce_forte_feito/0.


% --- Preload

ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    limpar_memoria_local,
    % Inicializa toda a memória de alvo, isca e grafo dentro de baitt.
    baitt:ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
                        IdOriginal, _ObjetivoOriginal),
    escolher_identidade_segura(Suspeitos, IdOriginal,
                               LadraoID, PlanoDisfarce),
    assertz(plano_disfarce_forte(PlanoDisfarce)),
    configurar_anti_marple(ObjetivoLadrao).


% --- Ação

% Intercepta somente o disfarce inicial. Depois, todas as decisões continuam
% sendo tomadas pelo baitt original.
ladrao_action(_, thief(_, _, _, _, Itens, Dsg),
              disfarce(Modificacoes)) :-
    Itens == [],
    \+ disfarce_forte_feito,
    plano_disfarce_forte(Modificacoes),
    Modificacoes \= [],
    length(Modificacoes, Quantidade),
    Quantidade =< Dsg,
    marcar_disfarce_feito,
    !.

% A obra de arte compartilha documento/passe, rádio/mapa e chave com outras
% cadeias. Roubar também codigo_alarme faz ouro_do_banco ficar pronto no mesmo
% momento, removendo a unicidade exigida pelo fechamento do Marple.
ladrao_action(_, thief(loc(whitechapel), _, _, obra_de_arte, Itens, _),
              roubar(codigo_alarme)) :-
    \+ memberchk(codigo_alarme, Itens),
    memberchk(radio_policial, Itens),
    !.
ladrao_action(_, thief(loc(Cidade), _, _, obra_de_arte, Itens, _),
              move(Cidade, Proxima)) :-
    \+ memberchk(codigo_alarme, Itens),
    memberchk(radio_policial, Itens),
    Cidade \= whitechapel,
    baitt:proximo_passo(Cidade, whitechapel, Proxima),
    !.

ladrao_action(Eventos, Estado, Acao) :-
    baitt:ladrao_action(Eventos, Estado, Acao).


% --- Identidade e plano de disfarce

% Edgar Wolfe (9) e Victor Graves (1) compartilham altura(media) e
% genero(gen1). Esses dois atributos sozinhos deixam três suspeitos possíveis.
% Os três atributos finais passam a apontar para Victor, enquanto o atributo
% exclusivo atletico é omitido.
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

aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, aparencia(Aparencia)), Suspeitos),
    !.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _Nome, aparencia(Aparencia)), Suspeitos).


% Também marca a memória privada do baitt. Isso impede que, no turno seguinte,
% ele tente aplicar seu disfarce antigo de uma única modificação.
marcar_disfarce_feito :-
    assertz(disfarce_forte_feito),
    retractall(baitt:disfarce_inicial_feito),
    assertz(baitt:disfarce_inicial_feito),
    retractall(baitt:disfarces_usados(_)),
    assertz(baitt:disfarces_usados(3)).

configurar_anti_marple(obra_de_arte) :-
    baitt:tesouro_conhecido(obra_de_arte, _, _),
    baitt:item_conhecido(codigo_alarme, _, _),
    !,
    retractall(baitt:objetivo_atual(_)),
    assertz(baitt:objetivo_atual(obra_de_arte)),
    retractall(baitt:tesouro_isca(_)),
    assertz(baitt:tesouro_isca(ouro_do_banco)),
    retractall(baitt:itens_isca(_)),
    assertz(baitt:itens_isca([codigo_alarme])).
configurar_anti_marple(Objetivo) :-
    baitt:objetivo_atual(Objetivo).

limpar_memoria_local :-
    retractall(plano_disfarce_forte(_)),
    retractall(disfarce_forte_feito).
