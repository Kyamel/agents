:- module(shortestd, [
    detetive_preload/5,
    detetive_action/3
]).

:- use_module(library(lists)).

:- dynamic known_edge/2.
:- dynamic known_city/1.
:- dynamic known_item/3.
:- dynamic known_treasure/3.
:- dynamic known_suspect/2.
:- dynamic known_lock/1.

%!  detetive_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto) is det.
%
%   Detetive preditivo: assume que o ladrao escolhe objetivos desbloqueados por
%   menor caminho e tenta fechar uma cidade prevista na proxima rota.
detetive_preload(Grafo, Suspeitos, Itens, Tesouros, pronto) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo), lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(known_item(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(known_treasure(Tesouro, Cidade, Requisitos))),
    forall(member(procurado(Id, Aparencia), Suspeitos),
           assertz(known_suspect(Id, Aparencia))).

%!  detetive_action(+Eventos, +EstadoDetetive, -Acao) is det.
%
%   Primeiro tenta bloquear a rota prevista do ladrao. Depois usa mandato como
%   pressao secundaria e se move em direcao ao ultimo roubo.
detetive_action(Eventos, _Estado, fechar(Cidade)) :-
    cidade_predita_para_bloqueio(Eventos, Cidade),
    lembrar_lock(Cidade),
    !.
detetive_action(_Eventos, detective(_, nenhum, Pistas), pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas),
    !.
detetive_action(_, detective(_, Mandato, _), inspecionar) :-
    Mandato \= nenhum,
    !.
detetive_action(Eventos, detective(loc(Cidade), _, _), move(Cidade, Proxima)) :-
    ultimo_roubo(Eventos, _Item, CidadeRoubo),
    Cidade \= CidadeRoubo,
    proximo_passo(Cidade, CidadeRoubo, Proxima),
    !.
detetive_action(_, detective(loc(Cidade), _, _), move(Cidade, Proxima)) :-
    melhor_patrulha(Cidade, Proxima),
    !.
detetive_action(_, _, nada).


% --- Predicao de rota do ladrao

%!  cidade_predita_para_bloqueio(+Eventos, -Cidade) is semidet.
%
%   Se ja houve roubo, usa a cidade do roubo mais recente como ultima posicao
%   conhecida do ladrao. Senao, fecha uma cidade provavel de primeira coleta.
cidade_predita_para_bloqueio(Eventos, Cidade) :-
    ultimo_roubo(Eventos, _Item, CidadeAtual),
    itens_roubados(Eventos, Roubados),
    melhor_alvo_previsto(CidadeAtual, Roubados, _Obj, CidadeAlvo),
    cidade_de_armadilha(CidadeAtual, CidadeAlvo, Cidade),
    \+ known_lock(Cidade),
    !.
cidade_predita_para_bloqueio(Eventos, Cidade) :-
    Eventos \= [],
    ultimo_roubo(Eventos, _Item, CidadeAtual),
    \+ known_lock(CidadeAtual),
    Cidade = CidadeAtual,
    !.
cidade_predita_para_bloqueio([], Cidade) :-
    primeira_cidade_provavel(Cidade),
    \+ known_lock(Cidade).

%!  cidade_de_armadilha(+Origem, +Destino, -Cidade) is semidet.
%
%   Fecha o proximo passo da rota prevista. Se o destino ja e a origem, fecha a
%   propria origem como armadilha de saida.
cidade_de_armadilha(Origem, Origem, Origem) :- !.
cidade_de_armadilha(Origem, Destino, Cidade) :-
    caminho_mais_curto(Origem, Destino, [Origem, Cidade | _]).

%!  melhor_alvo_previsto(+CidadeAtual, +Roubados, -Objeto, -CidadeObjeto) is semidet.
%
%   Escolhe o proximo objetivo assumindo um ladrao guloso por menor caminho e
%   menor cadeia restante de requisitos.
melhor_alvo_previsto(CidadeAtual, Roubados, Objeto, CidadeObjeto) :-
    findall(Score-Obj-CidadeObj,
        ( objetivo_disponivel_previsto(Roubados, Obj),
          cidade_do_objeto(Obj, CidadeObj),
          caminho_mais_curto(CidadeAtual, CidadeObj, Caminho),
          length(Caminho, Tamanho),
          dependencia_restante(Obj, Roubados, Restante),
          Score is Tamanho * 10 + Restante * 4
        ),
        Pares),
    keysort(Pares, [_-Objeto-CidadeObjeto | _]).

%!  objetivo_disponivel_previsto(+Roubados, -Objeto) is nondet.
%
%   Gera objetos que um ladrao de menor caminho poderia buscar agora: itens
%   necessarios desbloqueados ou tesouros cujos requisitos ja foram coletados.
objetivo_disponivel_previsto(Roubados, Tesouro) :-
    known_treasure(Tesouro, _Cidade, Requisitos),
    \+ member(Tesouro, Roubados),
    requisitos_satisfeitos(Requisitos, Roubados).
objetivo_disponivel_previsto(Roubados, Item) :-
    item_relevante(Item),
    \+ member(Item, Roubados),
    known_item(Item, _Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Roubados).

item_relevante(Item) :-
    known_treasure(_Tesouro, _Cidade, Requisitos),
    requisito_recursivo(Requisitos, Item).

dependencia_restante(Objeto, Roubados, Restante) :-
    known_treasure(Objeto, _Cidade, Requisitos),
    !,
    requisitos_totais(Requisitos, Todos),
    subtract(Todos, Roubados, Pendentes),
    length(Pendentes, Restante).
dependencia_restante(Objeto, Roubados, Restante) :-
    known_item(Objeto, _Cidade, Requisitos),
    requisitos_totais(Requisitos, Todos),
    subtract(Todos, Roubados, Pendentes),
    length(Pendentes, Restante).

primeira_cidade_provavel(Cidade) :-
    findall(Score-C,
        ( objetivo_disponivel_previsto([], Obj),
          cidade_do_objeto(Obj, C),
          grau(C, Grau),
          dependencia_restante(Obj, [], Restante),
          Score is Restante * 10 - Grau
        ),
        Pares),
    keysort(Pares, [_-Cidade | _]).

ultimo_roubo([roubo(Item, Cidade, _) | _], Item, Cidade) :- !.
ultimo_roubo([_ | Eventos], Item, Cidade) :-
    ultimo_roubo(Eventos, Item, Cidade).

itens_roubados(Eventos, Roubados) :-
    findall(Item, member(roubo(Item, _Cidade, _), Eventos), Itens),
    sort(Itens, Roubados).


% --- Requisitos e objetos

requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    member(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Req,
        requisito_recursivo(Requisitos, Req),
        Todos),
    sort(Todos, TodosUnicos).

requisito_recursivo(Requisitos, Req) :-
    member(Req, Requisitos).
requisito_recursivo(Requisitos, ReqIndireto) :-
    member(Req, Requisitos),
    known_item(Req, _Cidade, SubRequisitos),
    requisito_recursivo(SubRequisitos, ReqIndireto).

cidade_do_objeto(Objeto, Cidade) :-
    known_item(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    known_treasure(Objeto, Cidade, _).


% --- Mapa e busca

limpar_memoria :-
    retractall(known_edge(_, _)),
    retractall(known_city(_)),
    retractall(known_item(_, _, _)),
    retractall(known_treasure(_, _, _)),
    retractall(known_suspect(_, _)),
    retractall(known_lock(_)).

lembrar_aresta(A, B) :-
    assertz(known_edge(A, B)),
    assertz(known_edge(B, A)),
    lembrar_cidade(A),
    lembrar_cidade(B).

lembrar_cidade(Cidade) :-
    known_city(Cidade),
    !.
lembrar_cidade(Cidade) :-
    assertz(known_city(Cidade)).

lembrar_lock(Cidade) :-
    known_lock(Cidade),
    !.
lembrar_lock(Cidade) :-
    assertz(known_lock(Cidade)).

proximo_passo(Origem, Destino, Proxima) :-
    caminho_mais_curto(Origem, Destino, [Origem, Proxima | _]).

caminho_mais_curto(Origem, Destino, Caminho) :-
    setof(L-P,
        ( caminho_simples(Origem, Destino, [Origem], P),
          length(P, L)
        ),
        [_-Caminho | _]).

caminho_simples(Destino, Destino, Visitados, Caminho) :-
    reverse(Visitados, Caminho).
caminho_simples(Atual, Destino, Visitados, Caminho) :-
    known_edge(Atual, Vizinho),
    \+ member(Vizinho, Visitados),
    caminho_simples(Vizinho, Destino, [Vizinho | Visitados], Caminho).

melhor_patrulha(Cidade, Proxima) :-
    setof(Score-Vizinho,
        ( known_edge(Cidade, Vizinho),
          grau(Vizinho, Grau),
          Score is -Grau
        ),
        [_-Proxima | _]).

grau(Cidade, Grau) :-
    findall(V, known_edge(Cidade, V), Vs),
    sort(Vs, Unicos),
    length(Unicos, Grau).


% --- Mandato como pressao secundaria

possible_warrant(Pistas, Id, SubPistas) :-
    non_empty_subset(Pistas, SubPistas),
    compatible_suspects(SubPistas, Suspeitos),
    length(Suspeitos, K),
    K =< 2,
    member(Id, Suspeitos).

compatible_suspects(Pistas, Suspeitos) :-
    findall(Id, suspect_matches(Pistas, Id), Suspeitos).

suspect_matches(Pistas, Id) :-
    known_suspect(Id, aparencia(Atributos)),
    forall(member(Pista, Pistas), member(Pista, Atributos)).

non_empty_subset(Lista, Subset) :-
    subset_(Lista, Subset),
    Subset \= [].

subset_([], []).
subset_([X | Xs], [X | Ys]) :-
    subset_(Xs, Ys).
subset_([_ | Xs], Ys) :-
    subset_(Xs, Ys).
