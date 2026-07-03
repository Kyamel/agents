:- module(nomadt, [
    ladrao_preload/7,
    ladrao_action/3
]).

% nomadt = evasort SEM ISCA (exposição mínima).
%
% Hipótese: em mapas longos (metro, max_turnos 255) a estratégia de isca do baitt
% — roubar itens de OUTRAS cadeias para criar ambiguidade — é veneno: multiplica
% os roubos, revela a posição do ladrão dezenas de vezes e o faz demorar em
% cidades com vários itens. Isso dá tempo de sobra para os detetives posicionais
% (shortestd/huntd/balancedd/crença) travarem a cidade do roubo e pegá-lo na
% saída. A isca só compensa no england (30 turnos), onde a ambiguidade de
% identidade decide antes de o detetive cercar.
%
% nomadt mantém tudo do evasort (disfarce anti-marple, diversificação de objetivo,
% evasão do shortestd) mas DESLIGA a isca: vai direto e só pela cadeia real,
% minimizando exposição no jogo longo.

:- use_module('evasort.pl', []).


ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    evasort:ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
                           LadraoID, ObjetivoLadrao),
    desligar_isca.

% Zera a isca herdada do baitt (e o override anti-marple do baittpro), para que
% as clausulas de isca do baitt nunca disparem — o ladrão persegue só a cadeia
% real do tesouro-alvo.
desligar_isca :-
    retractall(baitt:tesouro_isca(_)),
    assertz(baitt:tesouro_isca(nenhum)),
    retractall(baitt:itens_isca(_)),
    assertz(baitt:itens_isca([])).


ladrao_action(Eventos, Estado, Acao) :-
    evasort:ladrao_action(Eventos, Estado, Acao).
