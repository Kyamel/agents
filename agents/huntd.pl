:- module(huntd, [
    detetive_preload/5,
    detetive_action/3
]).

:- dynamic known_edge/2.
:- dynamic known_city/1.
:- dynamic known_item/3.
:- dynamic known_treasure/3.
:- dynamic known_suspect/2.
:- dynamic known_lock/1.
:- dynamic estimate_loc/1.
:- dynamic estimated_stolen/1.
:- dynamic seen_robberies/1.
:- dynamic inspected_estimate/1.

%!  detetive_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto) is det.
%
%   Detetive cacador: combina mandato com perseguicao. Ele estima onde o
%   ladrao esta, atualiza a estimativa com eventos de roubo e simula um passo
%   provavel do ladrao por menor caminho.
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
%   Atualiza a estimativa e age: se tem mandato e acredita estar na cidade do
%   ladrao, inspeciona; senao, continua cacando a posicao estimada.
detetive_action(Eventos, detective(loc(Cidade), Mandato, Pistas), Acao) :-
    atualizar_estimativa(Eventos),
    escolher_acao(Cidade, Mandato, Pistas, Acao),
    !.
detetive_action(_, _, nada).


% --- Politica

escolher_acao(Cidade, Mandato, _Pistas, inspecionar) :-
    Mandato \= nenhum,
    estimate_loc(Cidade),
    \+ inspected_estimate(Cidade),
    assertz(inspected_estimate(Cidade)),
    !.
escolher_acao(_Cidade, nenhum, Pistas, pedir_mandato(Id, SubPistas)) :-
    possible_warrant(Pistas, Id, SubPistas),
    !.
escolher_acao(_Cidade, Mandato, _Pistas, fechar(Alvo)) :-
    Mandato \= nenhum,
    estimate_loc(Alvo),
    \+ known_lock(Alvo),
    lembrar_lock(Alvo),
    !.
escolher_acao(Cidade, _Mandato, _Pistas, move(Cidade, Proxima)) :-
    alvo_de_caca(Alvo),
    Cidade \= Alvo,
    proximo_passo(Cidade, Alvo, Proxima),
    !.
escolher_acao(Cidade, _Mandato, _Pistas, move(Cidade, Proxima)) :-
    melhor_patrulha(Cidade, Proxima),
    !.
escolher_acao(_, _, _, nada).

%!  alvo_de_caca(-Cidade) is semidet.
%
%   Usa a estimativa atual, projetada um passo a frente, como alvo.
alvo_de_caca(CidadeProjetada) :-
    estimate_loc(Cidade),
    itens_estimados(Roubados),
    projetar_ladrao(Cidade, Roubados, CidadeProjetada),
    !.
alvo_de_caca(Cidade) :-
    estimate_loc(Cidade).


% --- Estimativa do ladrao

%!  atualizar_estimativa(+Eventos) is det.
%
%   Eventos de roubo corrigem a posicao estimada. Sem evento novo, a estimativa
%   avanca um passo seguindo o plano provavel do ladrao.
atualizar_estimativa(Eventos) :-
    processar_eventos(Eventos, TeveRouboNovo),
    ( TeveRouboNovo == true
    -> true
    ; avancar_estimativa_sem_evento
    ).

processar_eventos(Eventos, TeveRouboNovo) :-
    findall(Item-Cidade, member(roubo(Item, Cidade, _), Eventos), Roubos),
    length(Roubos, Total),
    seen_robberies(Vistos),
    forall(member(Item-_, Roubos), lembrar_roubo(Item)),
    ( Total > Vistos,
      Roubos = [ItemNovo-CidadeNova | _]
    -> lembrar_roubo(ItemNovo),
       set_estimate(CidadeNova),
       retractall(seen_robberies(_)),
       assertz(seen_robberies(Total)),
       TeveRouboNovo = true
    ;  TeveRouboNovo = false
    ).

lembrar_roubo(Item) :-
    estimated_stolen(Item),
    !.
lembrar_roubo(Item) :-
    assertz(estimated_stolen(Item)).

set_estimate(Cidade) :-
    retractall(estimate_loc(_)),
    retractall(inspected_estimate(_)),
    assertz(estimate_loc(Cidade)).

avancar_estimativa_sem_evento :-
    estimate_loc(Cidade),
    itens_estimados(Roubados),
    projetar_ladrao(Cidade, Roubados, Proxima),
    !,
    set_estimate(Proxima).
avancar_estimativa_sem_evento.

itens_estimados(Itens) :-
    findall(Item, estimated_stolen(Item), Brutos),
    sort(Brutos, Itens).

%!  projetar_ladrao(+Cidade, +Roubados, -ProximaCidade) is semidet.
%
%   Simula um passo provavel do ladrao: se ele ja esta na cidade de um objetivo
%   disponivel, assume que ficara parado para roubar; caso contrario, avanca no
%   menor caminho ate o melhor objetivo previsto.
projetar_ladrao(Cidade, Roubados, Cidade) :-
    melhor_alvo_previsto(Cidade, Roubados, _Obj, Cidade),
    !.
projetar_ladrao(Cidade, Roubados, Proxima) :-
    melhor_alvo_previsto(Cidade, Roubados, _Obj, CidadeAlvo),
    proximo_passo(Cidade, CidadeAlvo, Proxima).

%!  melhor_alvo_previsto(+CidadeAtual, +Roubados, -Objeto, -CidadeObjeto) is semidet.
%
%   Assume um ladrao racional simples: vai para o objetivo disponivel mais
%   proximo, com desempate por menor cadeia restante.
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
    retractall(known_lock(_)),
    retractall(estimate_loc(_)),
    retractall(estimated_stolen(_)),
    retractall(seen_robberies(_)),
    retractall(inspected_estimate(_)),
    assertz(seen_robberies(0)).

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
    bfs([[Origem]], [Origem], Destino, CaminhoInvertido),
    reverse(CaminhoInvertido, Caminho).

bfs([[Destino | Resto] | _], _Visitados, Destino, [Destino | Resto]) :-
    !.
bfs([CaminhoAtual | OutrosCaminhos], Visitados, Destino, Caminho) :-
    estender_caminho(CaminhoAtual, Visitados, NovosCaminhos, NovosVizinhos),
    append(Visitados, NovosVizinhos, VisitadosAtualizado),
    append(OutrosCaminhos, NovosCaminhos, FilaAtualizada),
    bfs(FilaAtualizada, VisitadosAtualizado, Destino, Caminho).

estender_caminho([Atual | Visitados], JaVistos, NovosCaminhos, NovosVizinhos) :-
    findall(Vizinho,
        ( known_edge(Atual, Vizinho),
          \+ memberchk(Vizinho, JaVistos)
        ),
        NovosVizinhos),
    findall([Vizinho, Atual | Visitados],
        member(Vizinho, NovosVizinhos),
        NovosCaminhos).

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


% --- Mandato

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
