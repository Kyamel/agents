:- module(adaptt, [
    ladrao_preload/7,
    ladrao_action/3
]).

% adaptt = evasort ADAPTATIVO ao comprimento do jogo.
%
% Descoberta empírica (england 30 turnos vs metro 255 turnos):
%   - Jogo CURTO: a isca do baitt (roubar itens de outras cadeias p/ criar
%     ambiguidade de identidade/alvo) é decisiva — vence marpled/crença antes de
%     o detetive cercar. Sem ela, marpled despenca (100% -> 13%).
%   - Jogo LONGO: a isca é veneno — multiplica roubos, revela a posição dezenas
%     de vezes e faz o ladrão demorar; os detetives posicionais travam a cidade
%     do roubo e o pegam na saída. Desligar a isca leva o metro de ~0% a ~67%.
%
% Como não dá para saber o adversário, adaptamos ao ÚNICO sinal disponível e
% confiável do "tamanho" do jogo: max_turnos do cenário (carregado no módulo
% user). Jogo longo -> exposição mínima (sem isca); jogo curto -> isca ligada.
%
% Tudo o mais (disfarce anti-marple, diversificação de objetivo, evasão do
% shortestd) vem do evasort e vale nos dois regimes.

:- use_module('evasort.pl', []).

% Acima disto consideramos "jogo longo" e desligamos a isca. england=30 (curto),
% metro*=255 (longo). Qualquer corte em (30, 255) separa as duas famílias.
limite_jogo_longo(100).


ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
               LadraoID, ObjetivoLadrao) :-
    evasort:ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto,
                           LadraoID, ObjetivoLadrao),
    ( jogo_longo(Grafo) -> desligar_isca ; true ).

% Longo se max_turnos passar do limite. Se não der para ler max_turnos (cenário
% atípico), cai para heurística de tamanho do grafo (muitos vértices = mapa
% grande = jogo longo).
jogo_longo(_Grafo) :-
    catch(user:max_turnos(MT), _, fail),
    !,
    limite_jogo_longo(Limite),
    MT > Limite.
jogo_longo(Grafo) :-
    vertices_do_grafo(Grafo, Vertices),
    length(Vertices, N),
    N > 24.

vertices_do_grafo(Grafo, Vertices) :-
    findall(V, ( member(adj(A, B), Grafo), (V = A ; V = B) ), Todos),
    sort(Todos, Vertices).

% Zera a isca herdada do baitt (e o override anti-marple do baittpro), para que
% as clausulas de isca do baitt nunca disparem — o ladrão persegue só a cadeia
% real do tesouro-alvo, minimizando exposição.
desligar_isca :-
    retractall(baitt:tesouro_isca(_)),
    assertz(baitt:tesouro_isca(nenhum)),
    retractall(baitt:itens_isca(_)),
    assertz(baitt:itens_isca([])).


ladrao_action(Eventos, Estado, Acao) :-
    evasort:ladrao_action(Eventos, Estado, Acao).
