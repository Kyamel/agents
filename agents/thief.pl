:- module(thief, [
    ladrao_preload/7,
    ladrao_action/3
]).

:- use_module(library(lists)).

:- dynamic aresta_conhecida/2.
:- dynamic item_conhecido/3.
:- dynamic tesouro_conhecido/3.
:- dynamic suspeito_conhecido/1.
:- dynamic objetivo_atual/1.

%!  ladrao_preload(+Grafo, +Suspeitos, +Itens, +Tesouros, pronto, -LadraoID, -ObjetivoLadrao) is det.
%
%   Guarda o conhecimento inicial do mapa e escolhe uma identidade ambigua e
%   um tesouro com cadeia de requisitos pequena.
ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, LadraoID, ObjetivoLadrao) :-
    limpar_memoria,
    forall(member(adj(A, B), Grafo),
           lembrar_aresta(A, B)),
    forall(member(item(Item, Cidade, Requisitos), Itens),
           assertz(item_conhecido(Item, Cidade, Requisitos))),
    forall(member(tesouro(Tesouro, Cidade, Requisitos), Tesouros),
           assertz(tesouro_conhecido(Tesouro, Cidade, Requisitos))),
    forall(member(Suspeito, Suspeitos),
           assertz(suspeito_conhecido(Suspeito))),
    escolher_identidade(Suspeitos, LadraoID),
    escolher_tesouro(ObjetivoLadrao),
    assertz(objetivo_atual(ObjetivoLadrao)).

%!  ladrao_action(+Eventos, +EstadoLadrao, -Acao) is det.
%
%   Decide a proxima acao baseado em requisitos, cidade atual, requisitos_satisfeitos.
%   Disfarces sao ignorados.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, Vizinho)) :-
    % Se já tem o tesouro, fugir.
    member(Target, Itens),
    !,
    aresta_conhecida(Cidade, Vizinho).
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Target)) :-
    % Se o tesouro está aqui e pode roubar, roubar.
    tesouro_conhecido(Target, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), roubar(Item)) :-
    % Se o próximo item está aqui e pode roubar, roubar.
    proximo_objetivo(Target, Itens, Item),
    item_conhecido(Item, Cidade, Requisitos),
    requisitos_satisfeitos(Requisitos, Itens),
    !.
ladrao_action(_, thief(loc(Cidade), _, _, Target, Itens, _), move(Cidade, ProximaCidade)) :-
    % Senão, andar até a cidade do próximo objetivo.
    proximo_objetivo(Target, Itens, Objeto),
    cidade_do_objeto(Objeto, CidadeObjetivo),
    proximo_passo(Cidade, CidadeObjetivo, ProximaCidade),
    !.
ladrao_action(_, _, nada).


% --- Memoria inicial

%!  limpar_memoria is det.
%
%   Remove fatos dinamicos de partidas anteriores.
limpar_memoria :-
    retractall(aresta_conhecida(_, _)),
    retractall(item_conhecido(_, _, _)),
    retractall(tesouro_conhecido(_, _, _)),
    retractall(suspeito_conhecido(_)),
    retractall(objetivo_atual(_)).

%!  lembrar_aresta(+A, +B) is det.
%
%   Salva uma aresta como ida e volta, pois o mapa e usado como grafo nao
%   direcionado pelo agente.
lembrar_aresta(A, B) :-
    assertz(aresta_conhecida(A, B)),
    assertz(aresta_conhecida(B, A)).


% --- Escolhas do preload

%!  escolher_tesouro(-Tesouro) is det.
%
%   Escolhe o tesouro com menos requisitos totais, contando dependencias
%   recursivas de itens.
escolher_tesouro(Tesouro) :-
    findall(Quantidade-T,
        quantidade_requisitos_tesouro(T, Quantidade),
        Pares),
    keysort(Pares, [_MenorQuantidade-Tesouro | _]).

%!  quantidade_requisitos_tesouro(+Tesouro, -Quantidade) is det.
%
%   Conta quantos itens precisam ser roubados antes do tesouro.
quantidade_requisitos_tesouro(Tesouro, Quantidade) :-
    tesouro_conhecido(Tesouro, _Cidade, Requisitos),
    requisitos_totais(Requisitos, Todos),
    length(Todos, Quantidade).

%!  requisitos_totais(+Requisitos, -Todos) is det.
%
%   Expande uma lista de requisitos, incluindo requisitos dos proprios itens.
requisitos_totais(Requisitos, TodosUnicos) :-
    findall(Req,
        requisito_recursivo(Requisitos, Req),
        Todos),
    sort(Todos, TodosUnicos).

%!  requisito_recursivo(+Requisitos, -Req) is nondet.
%
%   Gera cada requisito direto e indireto de uma lista.
requisito_recursivo(Requisitos, Req) :-
    member(Req, Requisitos).
requisito_recursivo(Requisitos, ReqIndireto) :-
    member(Req, Requisitos),
    item_conhecido(Req, _Cidade, SubRequisitos),
    requisito_recursivo(SubRequisitos, ReqIndireto).

%!  escolher_identidade(+Suspeitos, -LadraoID) is det.
%
%   Prefere uma identidade cujos prefixos de aparencia ainda combinem com
%   muitos suspeitos. Isso reduz a utilidade das primeiras pistas reveladas.
escolher_identidade(Suspeitos, LadraoID) :-
    findall(Pontuacao-Id,
        ( aparencia_suspeito(Id, Suspeitos, Aparencia),
          pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao)
        ),
        Pares),
    keysort(Pares, Ordenados),
    reverse(Ordenados, [_MelhorPontuacao-LadraoID | _]).

%!  aparencia_suspeito(+Id, +Suspeitos, -Aparencia) is semidet.
%
%   Aceita os dois formatos de suspeito usados nos cenarios do projeto.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, _Nome, aparencia(Aparencia)), Suspeitos),
    !.
aparencia_suspeito(Id, Suspeitos, Aparencia) :-
    member(procurado(Id, aparencia(Aparencia)), Suspeitos).

%!  pontuacao_ambiguidade(+Aparencia, +Suspeitos, -Pontuacao) is det.
%
%   Soma quantos suspeitos sao compativeis com cada prefixo da aparencia.
pontuacao_ambiguidade(Aparencia, Suspeitos, Pontuacao) :-
    findall(Quantidade,
        ( prefixo(Aparencia, Prefixo),
          Prefixo \= [],
          contar_compativeis(Prefixo, Suspeitos, Quantidade)
        ),
        Quantidades),
    sum_list(Quantidades, Pontuacao).

%!  contar_compativeis(+Prefixo, +Suspeitos, -Quantidade) is det.
%
%   Conta suspeitos cuja aparencia comeca com o prefixo informado.
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


% --- Requisitos e proximo objetivo

%!  requisitos_satisfeitos(+Requisitos, +Itens) is semidet.
%
%   Verdadeiro quando todos os requisitos ja estao na lista de itens roubados.
requisitos_satisfeitos([], _).
requisitos_satisfeitos([Req | Resto], Itens) :-
    member(Req, Itens),
    requisitos_satisfeitos(Resto, Itens).

%!  proximo_objetivo(+Target, +Itens, -ProximoObjeto) is det.
%
%   Decide qual objeto deve ser buscado agora: primeiro um requisito pendente
%   mais profundo; se nao houver requisitos pendentes, o proprio tesouro.
proximo_objetivo(Target, Itens, ProximoObjeto) :-
    tesouro_conhecido(Target, _CidadeTesouro, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito(Req, Itens, ProximoObjeto).
proximo_objetivo(Target, _Itens, Target).

%!  resolver_requisito(+Item, +Itens, -ProximoObjeto) is det.
%
%   Se o item tambem depende de outros itens, desce recursivamente ate achar
%   algo que ja possa ser roubado primeiro.
resolver_requisito(Item, Itens, ProximoObjeto) :-
    item_conhecido(Item, _Cidade, Requisitos),
    requisito_pendente(Requisitos, Itens, Req),
    !,
    resolver_requisito(Req, Itens, ProximoObjeto).
resolver_requisito(Item, _Itens, Item).

%!  requisito_pendente(+Requisitos, +Itens, -Pendente) is semidet.
%
%   Retorna o primeiro requisito da lista que ainda nao foi roubado.
requisito_pendente([Req | _], Itens, Req) :-
    \+ member(Req, Itens),
    !.
requisito_pendente([Req | Resto], Itens, Pendente) :-
    member(Req, Itens),
    requisito_pendente(Resto, Itens, Pendente).

%!  cidade_do_objeto(+Objeto, -Cidade) is semidet.
%
%   Localiza a cidade onde um item ou tesouro pode ser roubado.
cidade_do_objeto(Objeto, Cidade) :-
    item_conhecido(Objeto, Cidade, _),
    !.
cidade_do_objeto(Objeto, Cidade) :-
    tesouro_conhecido(Objeto, Cidade, _).


% --- Busca no mapa

%!  proximo_passo(+Origem, +Destino, -ProximaCidade) is semidet.
%
%   Encontra um caminho curto ate o destino e devolve somente o primeiro passo.
proximo_passo(Origem, Destino, ProximaCidade) :-
    caminho_mais_curto(Origem, Destino, [Origem, ProximaCidade | _]).

%!  caminho_mais_curto(+Origem, +Destino, -Caminho) is semidet.
%
%   Busca em largura no grafo conhecido. Cada elemento da fila e um caminho
%   invertido, para ser barato adicionar vizinhos durante a expansao.
caminho_mais_curto(Origem, Destino, Caminho) :-
    bfs([[Origem]], Destino, CaminhoInvertido),
    reverse(CaminhoInvertido, Caminho).

bfs([[Destino | Resto] | _], Destino, [Destino | Resto]) :-
    !.
bfs([CaminhoAtual | OutrosCaminhos], Destino, Caminho) :-
    estender_caminho(CaminhoAtual, NovosCaminhos),
    append(OutrosCaminhos, NovosCaminhos, FilaAtualizada),
    bfs(FilaAtualizada, Destino, Caminho).

%!  estender_caminho(+Caminho, -NovosCaminhos) is det.
%
%   Gera caminhos novos a partir do ultimo no, evitando ciclos.
estender_caminho([Atual | Visitados], NovosCaminhos) :-
    findall([Vizinho, Atual | Visitados],
        ( aresta_conhecida(Atual, Vizinho),
          \+ member(Vizinho, [Atual | Visitados])
        ),
        NovosCaminhos).
