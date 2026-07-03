% ==============================================================================
% Agente Ladrão - CSI107 Linguagens de Programação
% Autores: <Nome> - <Matrícula>
%
% Estratégia:
%   - Calcula a ordem de roubo via ordenação topológica das dependências.
%   - Usa BFS para rota mínima entre cidades.
%   - No primeiro turno, gasta todos os disfarces disponíveis omitindo o máximo
%     de características para dificultar o mandato do detetive.
%   - Após roubar o tesouro, foge imediatamente (condição de vitória exige
%     estar em cidade diferente da do roubo).
%
% Observações sobre a máquina de jogo (Interactor.prolog):
%   - Eventos têm a forma roubo(Item, Cidade, Atributos), onde Atributos são
%     N características da aparência atual do ladrão (N = qtd itens já roubados
%     antes + 1). O ladrão vaza pistas a cada roubo.
%   - disfarce(LS) consome 1 unidade de disfarce independente do tamanho de LS.
%   - LS passado ao preload tem forma procurado(ID, AP), sem o nome.
%   - Condição de vitória: roubado(Tesouro, C1) e ladrão em C \= C1.
% ==============================================================================

:- module(ladrao, [ladrao_preload/7, ladrao_action/3]).

% ------------------------------------------------------------------------------
% Base de conhecimento dinâmica
% ------------------------------------------------------------------------------

:- dynamic lb_grafo/2.              % lb_grafo(X, Y) — aresta bidirecional
:- dynamic lb_item/3.               % lb_item(Nome, Cidade, Prereqs)
:- dynamic lb_tesouro/3.            % lb_tesouro(Nome, Cidade, Prereqs)
:- dynamic lb_plano/1.              % lb_plano([item1, ..., tesouro])
:- dynamic lb_disfarce_feito/0.     % flag: disfarce inicial já aplicado


% ------------------------------------------------------------------------------
% 1. PRÉ-CARGA
% ------------------------------------------------------------------------------

% ladrao_preload(+G, +LS, +LI, +LT, -Ready, -ID, -Obj)
%
% Nota: G  = [adj(X,Y), ...]
%       LS = [procurado(ID, aparencia([...])), ...]   (sem nome, conforme gameStart)
%       LI = [item(Nome, Cidade, Prereqs), ...]
%       LT = [tesouro(Nome, Cidade, Prereqs), ...]
ladrao_preload(G, _LS, LI, LT, pronto, ID, Obj) :-
    % Armazena grafo bidirecional
    forall(member(adj(X,Y), G), (
        assertz(lb_grafo(X,Y)),
        assertz(lb_grafo(Y,X))
    )),
    % Armazena itens e tesouros
    forall(member(item(N,C,XS),  LI), assertz(lb_item(N,C,XS))),
    forall(member(tesouro(N,C,XS), LT), assertz(lb_tesouro(N,C,XS))),
    % Escolhe o primeiro tesouro como objetivo
    lb_tesouro(Obj, _, _),
    % Escolhe o primeiro suspeito disponível no cenário como identidade
    procurado(ID, _, _),
    % Calcula o plano de roubo (ordem topológica das dependências)
    calcular_plano(Obj, Plano),
    assertz(lb_plano(Plano)).


% ------------------------------------------------------------------------------
% 2. PLANEJAMENTO — ordenação topológica das dependências
% ------------------------------------------------------------------------------

% calcular_plano(+Tesouro, -Plano)
calcular_plano(Tesouro, Plano) :-
    ordem_topologica(Tesouro, [], Plano).

% ordem_topologica(+Item, +Visitados, -Ordem)
ordem_topologica(Item, Visitados, Ordem) :-
    prereqs_do(Item, Prereqs),
    foldl(visitar_prereq, Prereqs, Visitados-[], _-OrdemAcc),
    append(OrdemAcc, [Item], Ordem).

visitar_prereq(P, Vis-Acc, NVis-NAcc) :-
    (   member(P, Vis)
    ->  NVis = Vis, NAcc = Acc
    ;   ordem_topologica(P, [P|Vis], SubOrdem),
        append(Acc, SubOrdem, NAcc),
        NVis = [P|Vis]
    ).

prereqs_do(Item, Prereqs) :-
    (   lb_tesouro(Item, _, Prereqs) -> true
    ;   lb_item(Item, _, Prereqs)
    ).


% ------------------------------------------------------------------------------
% 3. NAVEGAÇÃO — BFS para caminho mínimo
% ------------------------------------------------------------------------------

% caminho_minimo(+Orig, +Dest, -Caminho)
%   Caminho inclui Orig e Dest. Retorna o de menor número de arestas.
caminho_minimo(X, X, [X]) :- !.
caminho_minimo(Orig, Dest, Caminho) :-
    bfs([[Orig]], Dest, CamInv),
    reverse(CamInv, Caminho).

% bfs(+Fila, +Dest, -CaminhoInvertido)
bfs([[Dest|Resto]|_], Dest, [Dest|Resto]) :- !.
bfs([Atual|Resto], Dest, Caminho) :-
    Atual = [Cab|_],
    findall([Viz|Atual],
        (lb_grafo(Cab, Viz), \+ member(Viz, Atual)),
        Novos),
    append(Resto, Novos, NovaFila),
    bfs(NovaFila, Dest, Caminho).


% ------------------------------------------------------------------------------
% 4. AÇÃO PRINCIPAL
% ------------------------------------------------------------------------------

% ladrao_action(+Eventos, +Estado, -Acao)
ladrao_action(_Eventos, Estado, Acao) :-
    Estado = thief(loc(CidAtual), _ID, AP, _OBJ, ItensRoubados, Disfarces),
    lb_plano(Plano),
    proximo_alvo(Plano, ItensRoubados, ProximoAlvo),
    decidir_acao(CidAtual, ProximoAlvo, AP, Disfarces, Acao).


% ------------------------------------------------------------------------------
% 5. DECISÃO DE AÇÃO
% ------------------------------------------------------------------------------

% Caso 1: Primeiro turno com disfarces disponíveis — omite até Disfarces atributos.
%   Cada modificação custa 1 unidade (Dsg1 is Dsg-K, onde K=length(LS)).
decidir_acao(_CidAtual, _Alvo, AP, Disfarces, Acao) :-
    \+ lb_disfarce_feito,
    Disfarces > 0,
    !,
    assertz(lb_disfarce_feito),
    montar_disfarce_maximo(AP, Disfarces, Acao).

% Caso 2: Plano concluído — tesouro roubado, fugir imediatamente.
%   (condição de vitória exige C \= C1 onde C1 é a cidade do roubo)
decidir_acao(CidAtual, fim, _AP, _Disfarces, move(CidAtual, Viz)) :-
    !,
    lb_grafo(CidAtual, Viz).

% Caso 3: Está na cidade do alvo — roubar.
decidir_acao(CidAtual, Alvo, _AP, _Disfarces, roubar(Alvo)) :-
    cidade_do_alvo(Alvo, CidAtual),
    !.

% Caso 4: Mover em direção ao alvo pelo caminho mínimo (BFS).
decidir_acao(CidAtual, Alvo, _AP, _Disfarces, move(CidAtual, Proximo)) :-
    cidade_do_alvo(Alvo, CidAlvo),
    caminho_minimo(CidAtual, CidAlvo, [_|[Proximo|_]]),
    !.

% Fallback
decidir_acao(_, _, _, _, nada).


% ------------------------------------------------------------------------------
% 6. DISFARCE — omite todas as características em uma única ação (custo: 1)
% ------------------------------------------------------------------------------

% montar_disfarce_maximo(+Aparencia, +Orcamento, -Acao)
%   Constrói uma lista de omitir(X) para até Orcamento atributos reais
%   da aparência (cada omitir custa 1 unidade de disfarce).
montar_disfarce_maximo(aparencia(Attrs), Orcamento, disfarce(Mods)) :-
    include(attr_real, Attrs, Reais),
    Reais \= [],
    !,
    primeiros_n(Reais, Orcamento, Selecionados),
    maplist([A, omitir(A)]>>true, Selecionados, Mods).
montar_disfarce_maximo(_, _, nada).

% attr_real(+Attr): verdadeiro se o atributo não é um disfarce já aplicado.
attr_real(disfarce(_, _)) :- !, fail.
attr_real(_).


% ------------------------------------------------------------------------------
% 7. UTILITÁRIOS
% ------------------------------------------------------------------------------

% proximo_alvo(+Plano, +Roubados, -Alvo)
proximo_alvo([], _, fim) :- !.
proximo_alvo([H|T], Roubados, Alvo) :-
    (   member(H, Roubados)
    ->  proximo_alvo(T, Roubados, Alvo)
    ;   Alvo = H
    ).

% cidade_do_alvo(+Alvo, -Cidade)
cidade_do_alvo(Alvo, Cidade) :-
    (   lb_tesouro(Alvo, Cidade, _) -> true
    ;   lb_item(Alvo, Cidade, _)
    ).
