% ============================================================
% DETETIVE: naive_pursuer_d
%
% Perseguidor simples (implementacao de referencia). Tenta localizar o
% ladrao pelos eventos e caminhar ate ele por BFS; pede mandato quando as
% pistas deixam <=2 suspeitos e inspeciona ao alcanca-lo. A leitura de
% eventos e ingenua (espera um formato de evento diferente do que o
% motor emite), entao na pratica cai muito no movimento de fallback e
% captura pouco. Util como esqueleto e baseline fraco.
% ============================================================

:- module(naive_pursuer_d, [detetive_preload/5, detetive_action/3]).

% Base de conhecimento dinâmica interna do detetive para lembrar do cenário
:- dynamic mapa_ruas/2.
:- dynamic lista_suspeitos/1.

%! detetive_preload(+G, +LS, +LI, +LT, -Ready)
% Armazena as informações públicas do cenário e avisa que está pronto.
detetive_preload(G, LS, _LI, _LT, pronto) :-
    retractall(mapa_ruas(_,_)),
    retractall(lista_suspeitos(_)),
    assertz(lista_suspeitos(LS)),
    salvar_grafo(G).

% Auxiliar para salvar as arestas adj(X,Y) como conectados bidirecionais ou direcionados
salvar_grafo([]).
salvar_grafo([adj(X, Y)|Cauda]) :-
    assertz(mapa_ruas(X, Y)),
    assertz(mapa_ruas(Y, X)), % Remova se o grafo do cenário for estritamente direcionado
    salvar_grafo(Cauda).

%! detetive_action(+E, +St, -A)
% Determina a próxima ação com base nos eventos (E) e no estado atual (St).
detetive_action(Eventos, detective(loc(CidadeAtual), Mandato, Pistas), A) :-
    % 1. Se o detetive já tem o mandato e sabe que o ladrão está na mesma cidade -> INSPECCIONAR!
    Mandato \= nenhum,
    onde_esta_o_ladrao(Eventos, CidadeAtual),
    !,
    A = inspecionar.

% 2. Se não tem mandato, mas já tem pistas suficientes para incriminar alguém -> PEDIR MANDATO!
detetive_action(_Eventos, detective(loc(_), nenhum, Pistas), A) :-
    lista_suspeitos(Suspeitos),
    suspeito_valido(Suspeitos, Pistas, IDSuspeito),
    !,
    A = pedir_mandato(IDSuspeito, Pistas).

% 3. Se o detetive sabe onde o ladrão está (com base nos eventos), ele calcula o caminho e se move.
detetive_action(Eventos, detective(loc(CidadeAtual), _Mandato, _Pistas), A) :-
    onde_esta_o_ladrao(Eventos, CidadeLadrao),
    CidadeAtual \= CidadeLadrao,
    achar_caminho(CidadeAtual, CidadeLadrao, [CidadeAtual], [_ProximaCidade | _RestoCaminho]),
    !,
    A = move(CidadeAtual, _ProximaCidade).

% 4. Caso padrão: se não souber onde o ladrão está ou não houver caminho, move-se aleatoriamente ou fica parado.
detetive_action(_Eventos, detective(loc(CidadeAtual), _Mandato, _Pistas), A) :-
    mapa_ruas(CidadeAtual, Proxima),
    !,
    A = move(CidadeAtual, Proxima).
detetive_action(_Eventos, _St, nada).


% --- PREDICADOS AUXILIARES DE INTELIGÊNCIA ---

%! onde_esta_o_ladrao(+Eventos, -Cidade)
% Varre a lista de eventos de trás para frente para achar a última localização conhecida do ladrão.
% Você precisará adaptar os termos exatos de acordo com os functores gerados pela máquina de jogo.
onde_esta_o_ladrao([roubo(_Item, Cidade) | _], Cidade) :- !.
onde_esta_o_ladrao([movimento_ladrao(_, Cidade) | _], Cidade) :- !. % Exemplo de functor
onde_esta_o_ladrao([_ | Cauda], Cidade) :- onde_esta_o_ladrao(Cauda, Cidade).


%! suspeito_valido(+ListaSuspeitos, +Pistas, -IDEscolhido)
% Filtra a lista de suspeitos usando as pistas atuais.
% Se sobrarem no máximo 2 suspeitos, retorna o ID de um deles.
suspeito_valido(Suspeitos, Pistas, IDEscolhido) :-
    filtrar_suspeitos(Suspeitos, Pistas, Filtrados),
    length(Filtrados, Qtd),
    Qtd > 0,
    Qtd < 3,
    member(procurado(IDEscolhido, _, _), Filtrados).

filtrar_suspeitos([], _, []).
filtrar_suspeitos([procurado(ID, Nome, aparencia(Props)) | Cauda], Pistas, [procurado(ID, Nome, aparencia(Props)) | Filtrados]) :-
    % Verifica se as características batem com as pistas (precisa tratar possíveis disfarces do ladrão)
    contem_pistas(Props, Pistas),
    !,
    filtrar_suspeitos(Cauda, Pistas, Filtrados).
filtrar_suspeitos([_ | Cauda], Pistas, Filtrados) :-
    filtrar_suspeitos(Cauda, Pistas, Filtrados).

contem_pistas(_, []).
contem_pistas(Props, [Pista | Cauda]) :-
    member(Pista, Props), % Simplificado: assume correspondência direta
    contem_pistas(Props, Cauda).


%! achar_caminho(+Inicio, +Fim, +Visitados, -Caminho)
% Busca em largura (BFS) ou profundidade (DFS) simples para achar rotas no mapa.
achar_caminho(Fim, Fim, _, []).
achar_caminho(Inicio, Fim, Visitados, [Proxima | Caminho]) :-
    mapa_ruas(Inicio, Proxima),
    \+ member(Proxima, Visitados),
    achar_caminho(Proxima, Fim, [Proxima | Visitados], Caminho).
