# Estrategias para um agente ladrao

Este documento organiza linhas de pesquisa e ideias de implementacao para criar um agente ladrao competitivo para o jogo descrito em `src/engine/`. A ideia nao eh escolher uma unica solucao desde o inicio, mas mapear familias de estrategias, quando elas tendem a funcionar, onde podem falhar e que tipo de detetive pode explorar cada uma.

## 1. Modelo mental do jogo

Antes de pesquisar algoritmos, vale fixar o que o engine permite.

O ladrao implementa:

```prolog
ladrao_preload(Grafo, Suspeitos, Itens, Tesouros, pronto, ThiefID, ThiefObj).
ladrao_action(Eventos, EstadoLadrao, Acao).
```

No `preload`, o ladrao recebe o mapa, a lista de suspeitos, itens e tesouros. Ele tambem escolhe:

- `ThiefID`: qual suspeito ele sera.
- `ThiefObj`: qual tesouro ele tentara roubar.

Durante a partida, o estado do ladrao tem a forma:

```prolog
thief(loc(Cidade), Id, aparencia(Atributos), TesouroAlvo, ItensColetados, DisfarcesRestantes)
```

As acoes validas do ladrao sao:

- `move(Origem, Destino)`: move para uma cidade conectada.
- `roubar(ItemOuTesouro)`: pega um item/tesouro presente na cidade se todos os requisitos ja estiverem nos itens coletados.
- `disfarce(ListaDeMudancas)`: altera a aparencia, consumindo usos de disfarce.
- `despir_disfarce`: remove disfarces e volta a aparencia original.
- `nada`: passa o turno.

O ladrao vence quando:

- roubou o tesouro-alvo;
- esta com o tesouro na lista de itens;
- saiu da cidade onde o tesouro estava originalmente.

Isso esta em `termino/2`: se o tesouro foi roubado em `C1` e o ladrao esta em outra cidade `C`, o vencedor eh `ladrao`.

O detetive vence se:

- tiver um mandato para o ID correto do ladrao;
- estiver na mesma cidade do ladrao;
- executar `inspecionar`.

O detetive tambem pode `fechar(Cidade)`. Se o ladrao tentar sair de uma cidade fechada, ele eh capturado. Isso torna gargalos do grafo perigosos.

## 2. Informacao revelada ao detetive

Cada roubo gera um evento:

```prolog
roubo(Item, Cidade, AtributosRevelados)
```

O evento informa:

- qual item foi roubado;
- em qual cidade;
- algumas caracteristicas da aparencia atual do ladrao.

A quantidade de atributos revelados cresce com o numero de roubos ja feitos:

- no primeiro roubo, revela 1 atributo;
- no segundo, revela 2;
- no terceiro, revela 3;
- e assim por diante, limitado pelo tamanho da lista de aparencia.

O detalhe importante: se o ladrao estiver disfarcado, os atributos revelados sao da aparencia disfarcada. Portanto, o disfarce nao esconde apenas identidade; ele polui o conjunto de pistas usado pelo detetive para pedir mandato.

## 3. O que pesquisar primeiro

### 3.1 Busca em grafos com custo uniforme

Pesquisar:

- BFS em Prolog.
- Menor caminho em grafo nao ponderado.
- Planejamento de rotas com pre-requisitos.
- Busca em espaco de estados.

Por que eh util:

O ladrao precisa coletar uma cadeia de itens antes de roubar o tesouro. Isso nao eh apenas encontrar o menor caminho entre duas cidades; eh resolver uma sequencia de objetivos com dependencias. Um estado util pode ser:

```text
(cidade_atual, itens_coletados)
```

A partir desse estado, as transicoes sao:

- mover para vizinhos;
- roubar itens disponiveis cujos requisitos ja foram cumpridos.

Com BFS, da para encontrar um plano minimo em numero de turnos para roubar um tesouro e sair da cidade final.

Onde eh forte:

- mapas pequenos e medios;
- cenarios em que o detetive nao bloqueia bem;
- escolha automatica do tesouro mais rapido;
- evita planos codificados manualmente que quebram quando o cenario muda.

Onde eh fraca:

- ignora risco de captura;
- tende a produzir rotas previsiveis;
- se todos os detetives conhecem o mapa e usam heuristica de menor caminho, eles podem antecipar o trajeto.

Como melhorar:

Use o menor caminho como baseline e depois adicione penalidades de risco: cidades de gargalo, cidades recem-reveladas por eventos, cidades proximas do detetive inferido e cidades que o detetive provavelmente fecharia.

### 3.2 Planejamento com pre-condicoes

Pesquisar:

- STRIPS planning.
- Partial-order planning.
- Goal regression.
- Dependency graph.
- Topological sort.

Por que eh util:

Itens e tesouros possuem pre-requisitos. Exemplo do `cenario1.prolog`:

```prolog
tesouro(coroa_real, j, [chave_real, codigo_cofre, luvas_laser, mapa_sigilo]).
item(chave_real, d, [mini_chave]).
item(luvas_laser, b, [bateria]).
```

Para roubar `coroa_real`, nao basta ir para `j`; antes eh necessario resolver uma arvore de dependencias. Um planejador pode expandir o objetivo:

```text
coroa_real
  chave_real
    mini_chave
  codigo_cofre
  luvas_laser
    bateria
  mapa_sigilo
```

Onde eh forte:

- permite escolher tesouros por custo real, nao por intuicao;
- facilita adaptar o ladrao para qualquer cenario;
- evita tentar roubar item ilegalmente antes dos requisitos.

Onde eh fraca:

- se o planejamento considerar apenas dependencias, pode escolher uma ordem ruim espacialmente;
- pode gerar plano otimo de coleta, mas ruim contra detetives que bloqueiam ou perseguem eventos.

Como melhorar:

Combine dependencias com distancia no grafo. Primeiro descubra o conjunto de itens necessarios para cada tesouro. Depois resolva a ordem de visita considerando a cidade inicial e o custo de deslocamento.

### 3.3 Problema do caixeiro viajante pequeno

Pesquisar:

- Traveling Salesman Problem para poucos pontos.
- Permutacoes em Prolog.
- Held-Karp dynamic programming.
- Orienteering problem.

Por que eh util:

Depois de expandir os requisitos, o ladrao tera uma lista de cidades obrigatorias. Em cenarios pequenos, da para testar todas as ordens possiveis respeitando dependencias e escolher a menor rota.

Exemplo:

```text
Preciso roubar itens em: a, d, b, e, c, j.
Qual ordem minimiza movimentos e respeita pre-requisitos?
```

Onde eh forte:

- muito bom para mapas pequenos de competicao;
- gera rotas mais curtas que uma heuristica gulosa;
- pode ser implementado sem bibliotecas externas.

Onde eh fraca:

- cresce mal se houver muitos itens obrigatorios;
- nao considera detetive, pistas e bloqueios;
- pode ficar caro se o agente recalcular tudo a cada turno sem cache.

Como melhorar:

Use forca bruta apenas para poucos objetivos. Para muitos objetivos, use uma heuristica gulosa com revisao local: escolher o objetivo disponivel mais proximo e depois tentar trocar pares de visitas para reduzir o caminho.

### 3.4 Caminhos alternativos e k-menores caminhos

Pesquisar:

- Yen's algorithm.
- K shortest paths.
- Rotas alternativas em grafos.
- Edge-disjoint paths e vertex-disjoint paths.

Por que eh util:

O detetive pode fechar cidades. Uma rota unica e otima pode ser fragil se passa por gargalos. Ter duas ou tres rotas candidatas permite reagir quando uma cidade se torna perigosa.

Onde eh forte:

- reduz dependencia de uma rota previsivel;
- ajuda contra detetives que fecham a cidade seguinte ao roubo;
- melhora sobrevivencia em mapas com ciclos.

Onde eh fraca:

- em grafo muito pequeno, talvez nao existam alternativas reais;
- rotas alternativas podem gastar turnos demais;
- escolher uma alternativa ruim pode dar tempo para o detetive conseguir mandato.

Como melhorar:

Calcule rotas candidatas e atribua custo composto:

```text
custo = distancia + risco_gargalo + risco_evento + risco_bloqueio
```

Nao escolha sempre a menor. Escolha a rota com melhor custo ajustado.

### 3.5 Centralidade e gargalos do mapa

Pesquisar:

- Articulation points.
- Bridges em grafos.
- Betweenness centrality.
- Graph cut.
- Choke points em jogos.

Por que eh util:

O detetive pode fechar uma cidade. Se o ladrao esta em uma cidade fechada e tenta sair, perde. Portanto, algumas cidades sao muito perigosas: pontos de articulacao, gargalos e regioes por onde muitos caminhos passam.

Onde eh forte:

- evita morrer por bloqueios simples;
- ajuda a decidir quando desviar;
- permite escolher tesouros menos expostos.

Onde eh fraca:

- se o menor plano necessariamente passa por gargalo, evitar demais pode impedir a vitoria;
- um detetive pode fechar cidades nao por centralidade, mas por inferencia de objetivo;
- em mapas pequenos, quase toda rota pode passar pelos mesmos pontos.

Como melhorar:

Nao trate gargalo como proibido. Trate como custo maior. Se passar por ele economiza muitos turnos, talvez ainda valha a pena, mas o ladrao deve tentar atravessar antes de revelar pistas importantes.

## 4. Estrategias de escolha do tesouro

### 4.1 Escolher o tesouro de menor plano

Ideia:

No `ladrao_preload`, calcular o custo estimado para cada tesouro e escolher o menor.

Justificativa:

O jogo tem limite de turnos. Quanto mais curto o plano, menos eventos o detetive recebe e menos chances ele tem de pedir mandato e interceptar.

Onde eh forte:

- contra detetives lentos;
- contra detetives que esperam muitas pistas antes de agir;
- em cenarios com grande diferenca de custo entre tesouros.

Onde eh fraca:

- se todos os ladroes escolherem o tesouro mais rapido, detetives podem se especializar nele;
- o tesouro mais rapido pode passar por cidades faceis de bloquear;
- uma rota curta pode revelar pistas muito cedo em cidades obvias.

O que pesquisar:

- shortest path with prerequisites;
- multi-goal path planning;
- heuristic search.

### 4.2 Escolher o tesouro menos previsivel

Ideia:

Nao escolher necessariamente o tesouro mais barato. Escolher entre os melhores com algum criterio de aleatoriedade ou risco menor.

Justificativa:

Em competicao, detetives podem aprender os padroes dos ladroes. Se o ladrao sempre escolhe o plano minimo, ele fica facil de modelar.

Onde eh forte:

- contra detetives que fazem inferencia por rota padrao;
- contra detetives codificados para um cenario especifico;
- em partidas repetidas.

Onde eh fraca:

- pode gastar turnos demais;
- aleatoriedade sem criterio vira autossabotagem;
- se o limite de turnos for apertado, desvio pode causar empate.

O que pesquisar:

- mixed strategy em teoria dos jogos;
- randomized algorithms;
- softmax action selection.

Implementacao pratica:

Calcule custo dos tesouros e escolha aleatoriamente entre os que estao ate certo percentual do melhor:

```text
melhor_custo = 10
candidatos = tesouros com custo <= 13
```

Assim o ladrao varia sem escolher planos absurdamente ruins.

### 4.3 Escolher o tesouro com menor assinatura de pistas

Ideia:

O custo de um tesouro nao eh apenas movimento. Cada item roubado gera evento e revela atributos. Um tesouro que exige menos roubos pode ser melhor mesmo se exigir mais movimento.

Justificativa:

O detetive precisa de pistas para pedir mandato. Em `validar(pedir_mandato/2)`, o conjunto de atributos deve reduzir os suspeitos para no maximo 2 e incluir o suspeito escolhido. Menos roubos significam menos atributos revelados.

Onde eh forte:

- contra detetives que buscam mandato rapido;
- quando suspeitos possuem atributos muito distintivos;
- quando o tesouro tem poucos requisitos.

Onde eh fraca:

- caminhar demais pode permitir interceptacao espacial;
- se os primeiros atributos ja identificam muito bem o ladrao, poucos roubos ainda podem bastar;
- se o detetive usa bloqueios em vez de mandato, menos pistas nao resolve tudo.

O que pesquisar:

- information gain;
- entropy;
- decision tree attribute selection;
- anonymity set.

Metrica sugerida:

Para cada plano, simular quais atributos seriam revelados em cada roubo e medir quantos suspeitos continuam compativeis. Quanto maior o conjunto de suspeitos compativeis, melhor para o ladrao.

## 5. Estrategias de identidade e disfarce

### 5.1 Escolher o suspeito mais ambiguo

Ideia:

No `ladrao_preload`, escolher um `ThiefID` cujos atributos se confundam melhor com outros suspeitos.

Justificativa:

O detetive so consegue pedir mandato se os atributos acumulados filtrarem para no maximo 2 suspeitos. Se o ladrao escolher uma identidade cujos primeiros atributos sejam compartilhados, ele atrasa o mandato.

Onde eh forte:

- contra detetives baseados em pistas;
- em cenarios com muitos suspeitos e atributos repetidos;
- quando os primeiros roubos revelam atributos pouco distintivos.

Onde eh fraca:

- a ordem dos atributos na lista importa, porque `takeAttr/3` revela os primeiros N atributos;
- se todos os suspeitos sao bem distintos, ambiguidade real pode ser baixa;
- nao ajuda contra detetive que captura por posicao sem mandato inicialmente, porque ele ainda precisa mandato, mas pode preparar interceptacao.

O que pesquisar:

- k-anonymity;
- entropy of attributes;
- feature uniqueness;
- set similarity.

Metrica simples:

Para cada suspeito, pegue prefixos da lista de atributos:

```text
prefixo tamanho 1
prefixo tamanho 2
prefixo tamanho 3
...
```

Conte quantos suspeitos combinam com cada prefixo. Prefira identidades cujo prefixo mantenha mais suspeitos por mais tempo.

### 5.2 Disfarce para preservar ambiguidade

Ideia:

Usar `disfarce/1` antes de roubos importantes para trocar, omitir ou adicionar atributos que aparecem nos eventos.

Justificativa:

O evento usa a aparencia atual. Se o ladrao muda os primeiros atributos revelados, o detetive pode acumular pistas que apontam para outro conjunto de suspeitos ou que nao identificam ninguem de forma limpa.

Onde eh forte:

- contra detetives que pedem mandato assim que possivel;
- antes de roubos iniciais, porque poucos atributos tem grande impacto;
- quando o ladrao sabe quais atributos sao distintivos.

Onde eh fraca:

- ha limite de disfarces (`ENGINE_QDIS`, padrao 3);
- gastar disfarce demais cedo pode deixar roubos finais expostos;
- um detetive robusto pode considerar a possibilidade de disfarce e tratar pistas como ruidosas.

O que pesquisar:

- adversarial examples em classificacao;
- noisy observations;
- deception planning;
- belief manipulation.

Padroes de disfarce a comparar:

- `omitir(Atributo)`: remove uma pista real, mas pode revelar `none`.
- `trocar(Antigo, Novo)`: substitui por outro atributo do mesmo functor, util para parecer outro suspeito.
- `adicionar(Novo)`: adiciona atributo novo no inicio da lista, podendo controlar o que aparece nos primeiros eventos.

Observacao importante:

`adicionar(X)` coloca `disfarce(X, none)` no inicio da aparencia. Como `takeAttr/3` percorre a lista do comeco, adicionar atributos pode ser uma forma poderosa de controlar as primeiras pistas reveladas.

### 5.3 Disfarce direcionado para outro suspeito

Ideia:

Escolher um suspeito-alvo falso e alterar a aparencia para que os eventos parecam compatíveis com ele.

Justificativa:

Se o detetive acumula pistas que apontam para o suspeito errado, ele pode pedir mandato errado ou gastar turnos tentando fechar/interceptar uma rota inferida incorretamente.

Onde eh forte:

- contra detetives que confiam muito em pistas;
- quando existe outro suspeito com atributos parecidos;
- se o suspeito falso tem tesouro/rota esperada diferente na heuristica do detetive.

Onde eh fraca:

- o engine valida mandato exigindo que o ID escolhido esteja entre os suspeitos compatíveis. Se as pistas excluirem o ladrao real, um detetive cuidadoso pode perceber ruido, mas um detetive simples pode falhar ao pedir mandato correto;
- trocar muitos atributos consome capacidade do disfarce;
- se a competicao tiver detetives que ignoram pistas inconsistentes, o beneficio cai.

O que pesquisar:

- decoy strategy;
- false trail generation;
- opponent modeling.

### 5.4 Guardar disfarce para os roubos finais

Ideia:

Nao usar disfarce no inicio; guardar para quando os eventos passariam a revelar muitos atributos.

Justificativa:

Como o numero de atributos revelados cresce a cada roubo, os roubos finais entregam mais informacao. Usar disfarce tarde pode impedir a conclusao do mandato.

Onde eh forte:

- contra detetives que precisam de 3 ou mais pistas;
- em tesouros com muitos requisitos;
- quando os primeiros atributos reais ainda sao ambiguos.

Onde eh fraca:

- se os primeiros atributos ja identificam o ladrao, guardar disfarce eh tarde demais;
- pode ser capturado antes de usar;
- se o primeiro roubo ocorre em cidade muito informativa, o detetive pode bloquear a rota mesmo sem mandato.

O que pesquisar:

- resource allocation;
- optimal stopping;
- value of information.

## 6. Estrategias contra diferentes detetives

### 6.1 Detetive guloso por pista

Comportamento esperado:

- sempre acumula eventos;
- pede mandato assim que o conjunto de suspeitos fica pequeno;
- tenta inspecionar quando acredita estar perto.

Como explorar:

- escolher suspeito ambiguo;
- usar disfarce antes dos roubos mais informativos;
- escolher tesouro com poucos roubos;
- gerar pistas falsas com `adicionar/1` ou `trocar/2`.

Fraqueza da estrategia:

Se o detetive tambem usa inferencia espacial, ele pode ignorar parte da identidade e se posicionar perto do proximo objetivo.

### 6.2 Detetive bloqueador de gargalos

Comportamento esperado:

- fecha cidades centrais;
- fecha cidade vizinha ao local do roubo;
- tenta capturar o ladrao quando ele sair de cidade fechada.

Como explorar:

- evitar rotas com gargalos depois de eventos;
- cruzar gargalos antes de roubar;
- preferir tesouros com rotas alternativas;
- recalcular rota quando uma cidade fica perigosa.

Fraqueza da estrategia:

Rotas alternativas podem atrasar demais. Se o detetive nao for bom em bloqueios, o ladrao pode estar desperdicando turnos.

### 6.3 Detetive perseguidor de menor caminho

Comportamento esperado:

- apos um roubo em `Cidade`, assume que o ladrao esta perto dela;
- move pelo menor caminho ate objetivos provaveis;
- tenta interceptar o caminho minimo entre item e proximo requisito.

Como explorar:

- fazer pequenas rotas de despiste;
- escolher entre multiplos proximos objetivos quando possivel;
- nao seguir sempre o caminho minimo;
- usar aleatoriedade controlada.

Fraqueza da estrategia:

Desvios custam turnos. O ladrao pode transformar uma vitoria curta em empate.

### 6.4 Detetive especializado no cenario

Comportamento esperado:

- conhece rotas otimas para cada tesouro;
- apos o primeiro roubo, infere qual tesouro esta sendo buscado;
- fecha a proxima cidade critica.

Como explorar:

- escolher tesouro de forma mista, nao fixa;
- mudar a ordem de coleta quando houver independencia entre itens;
- usar rotas secundarias;
- escolher identidades/disfarces que confundam mandato.

Fraqueza da estrategia:

Se o cenario tiver poucas alternativas, a especializacao do detetive continua forte. Nesse caso, o ladrao deve priorizar velocidade e controle de pistas.

### 6.5 Detetive conservador

Comportamento esperado:

- demora para pedir mandato;
- usa muitos `nada`, `fechar` ou movimentos pouco agressivos;
- tenta evitar mandato errado.

Como explorar:

- escolher rota mais curta;
- reduzir desvios;
- usar disfarce so quando nao custar movimento;
- finalizar o tesouro rapidamente.

Fraqueza da estrategia:

Se o detetive conservador tiver bom posicionamento, correr pelo caminho minimo pode passar exatamente pela interceptacao.

## 7. Heuristicas de risco

Uma implementacao forte pode atribuir nota para cada acao candidata.

### 7.1 Risco por cidade

Fatores possiveis:

- cidade apareceu em evento recente;
- cidade eh gargalo;
- cidade tem grau baixo, oferecendo poucas saidas;
- cidade eh requisito obvio para o tesouro escolhido;
- cidade ja foi fechada antes ou seria uma boa candidata a fechamento.

Uso:

Ao escolher entre dois caminhos de mesmo tamanho, preferir o que passa por menor risco.

Fraqueza:

Risco mal calibrado pode fazer o ladrao evitar caminhos bons e gastar turnos.

### 7.2 Risco por tempo

Fatores possiveis:

- quantos turnos faltam;
- quantos itens ainda faltam;
- distancia ate o tesouro;
- distancia minima para sair da cidade do tesouro depois de roubar.

Uso:

Se o tempo estiver apertado, reduzir despistes e escolher menor caminho. Se houver folga, aceitar rota mais segura.

Fraqueza:

Uma politica muito agressiva no fim pode ficar previsivel.

### 7.3 Risco por informacao

Fatores possiveis:

- quantos atributos serao revelados no proximo roubo;
- quantos suspeitos continuariam compativeis;
- se a proxima pista permite mandato;
- se vale gastar disfarce antes do roubo.

Uso:

Antes de cada `roubar/1`, simular a pista que sera emitida e decidir se usa `disfarce/1`.

Fraqueza:

Se o detetive nao usa pistas bem, otimizar informacao pode ser menos importante que velocidade.

## 8. Arquitetura sugerida para o agente

### 8.1 Preload

No `ladrao_preload/7`:

1. Normalizar o grafo como arestas bidirecionais.
2. Indexar itens por nome, cidade e requisitos.
3. Para cada tesouro:
   - expandir dependencias;
   - estimar quantidade de roubos;
   - estimar menor rota;
   - estimar risco de gargalos;
   - estimar exposicao de pistas.
4. Escolher `ThiefObj`.
5. Escolher `ThiefID` mais ambiguo para o plano escolhido.

Limite pratico:

O `ladrao_preload/7` precisa retornar `ThiefID` e `ThiefObj`, mas o estado persistente do agente nao aparece diretamente no contrato. Se for usar fatos dinamicos para guardar plano, precisa verificar se o sandbox/engine aceita isso no ambiente de submissao. Como `:- use_module` e `consult` sao bloqueados, a solucao deve ficar no proprio arquivo do agente.

### 8.2 Action

No `ladrao_action/3`:

1. Ler cidade atual, itens coletados, aparencia e disfarces restantes.
2. Se o item/tesouro da cidade esta disponivel e seus requisitos foram cumpridos:
   - avaliar se deve disfarcar antes;
   - se nao precisar disfarcar, `roubar(Item)`.
3. Se ja roubou o tesouro:
   - mover para qualquer cidade vizinha segura para vencer.
4. Caso contrario:
   - escolher proximo objetivo disponivel;
   - calcular proximo passo;
   - evitar cidade provavelmente fechada/perigosa se houver alternativa.

### 8.3 Replanejamento

Pesquisar:

- online planning;
- receding horizon planning;
- model predictive control em jogos;
- replanning under uncertainty.

Por que eh util:

O detetive age entre os turnos do ladrao. Mesmo que o ladrao tenha um plano inicial, eventos, bloqueios e posicoes reveladas no replay podem exigir mudanca.

No estado passado ao ladrao nao aparece diretamente a lista de cidades fechadas nem a posicao do detetive. O ladrao recebe `Eventos`, que sao eventos de roubo, nao eventos de fechamento. Portanto, o replanejamento do ladrao e limitado: ele pode reagir ao proprio progresso, mas nao observa tudo. Isso torna importante evitar planos que dependem de saber exatamente o que o detetive fez.

## 9. Ideias especificas para o `cenario1.prolog`

O cenario tem 10 cidades (`a` ate `j`), 3 tesouros e varias cadeias de requisitos.

### 9.1 `diamante_azul`

Requisitos:

- `cartao_magnetico` em `f`, sem requisito.
- `broca_termica` em `g`, exige `combustivel`.
- `combustivel` em `b`, sem requisito.
- `senha_banco` em `a`, sem requisito.
- tesouro em `h`.

Possivel leitura estrategica:

- exige poucos sub-requisitos;
- passa por regioes centrais;
- pode ser relativamente rapido dependendo da cidade inicial.

Forca:

- bom candidato para estrategia de velocidade.

Fraqueza:

- cidades como `b`, `g`, `h` e conexoes centrais podem ser previsiveis para detetives especializados.

### 9.2 `coroa_real`

Requisitos:

- `mini_chave` em `a`;
- `chave_real` em `d`;
- `codigo_cofre` em `e`;
- `bateria` em `d`;
- `luvas_laser` em `b`;
- `mapa_sigilo` em `c`;
- tesouro em `j`.

Possivel leitura estrategica:

- muitos itens, muitos eventos e muitas pistas;
- parte dos itens fica perto do lado esquerdo/superior do mapa;
- finalizar em `j` exige sair de `j` depois do roubo.

Forca:

- pode haver varias ordens para alguns itens, permitindo variar rota.

Fraqueza:

- muitos roubos revelam muitos atributos;
- detetive ganha mais tempo para pedir mandato;
- `j` eh final de mapa e pode ser previsivel.

### 9.3 `reliquia_antiga`

Requisitos:

- `livro_ritual` em `f`;
- `amuleto_sagrado` em `h`;
- `pergaminho` em `i`;
- `gazua` em `j`;
- `chave_catacumba` em `j`;
- `lanterna_uv` em `c`;
- `pe_de_cabra` em `e`;
- tesouro em `i`.

Possivel leitura estrategica:

- muitos itens, mas espalhados por regioes que podem permitir rotas alternativas;
- envolve `h`, `i`, `j`, que ficam na parte final do grafo.

Forca:

- pode confundir detetives que esperam o plano mais curto;
- rota pode se misturar com caminhos de outros tesouros.

Fraqueza:

- muitos roubos;
- muito tempo para o detetive acumular pistas;
- final em `i` tambem exige sair apos roubar.

## 10. Algoritmos e topicos para pesquisar

### Essenciais

- BFS em Prolog para menor caminho.
- Busca em espaco de estados `(cidade, itens)`.
- Expansao recursiva de requisitos.
- Ordenacao topologica de dependencias.
- Heuristicas gulosas para escolha do proximo item.
- Calculo de todos os prefixos de atributos e tamanho do conjunto de suspeitos compativeis.

### Intermediarios

- A* search com heuristica de distancia ate o objetivo.
- K shortest paths.
- Articulation points e bridges.
- Betweenness centrality.
- TSP pequeno com restricoes de precedencia.
- Teoria da informacao: entropia e ganho de informacao.

### Avancados

- Planejamento adversarial.
- Minimax com estado parcialmente observavel.
- Monte Carlo rollouts.
- Opponent modeling.
- Mixed strategies.
- POMDPs.

## 11. Ordem recomendada de implementacao

### Versao 1: ladrao planejador simples

Objetivo:

- escolher tesouro de menor custo;
- coletar requisitos na ordem correta;
- mover por menor caminho;
- roubar e sair da cidade do tesouro.

Por que fazer primeiro:

Sem isso, qualquer estrategia sofisticada fica em cima de uma base fraca. A primeira meta eh vencer detetives simples.

### Versao 2: escolha melhor de identidade

Objetivo:

- escolher `ThiefID` com maior ambiguidade nos prefixos de atributos.

Por que fazer depois:

Nao muda a rota, mas melhora a resistencia contra mandato.

### Versao 3: disfarce antes de roubos criticos

Objetivo:

- simular atributos revelados;
- usar `adicionar/1` ou `trocar/2` quando o proximo roubo reduziria suspeitos demais.

Por que fazer depois:

Disfarce so vale a pena quando o agente ja sabe quando vai roubar e quantas pistas isso revelaria.

### Versao 4: risco de gargalos

Objetivo:

- penalizar cidades centrais e gargalos;
- preferir rotas alternativas quando custo extra for pequeno.

Por que fazer depois:

Evita perder para detetives bloqueadores sem destruir a estrategia de velocidade.

### Versao 5: aleatoriedade controlada

Objetivo:

- variar entre planos quase otimos;
- variar ordem de itens independentes;
- variar suspeito entre opcoes boas.

Por que fazer por ultimo:

Aleatoriedade sem uma politica base forte so cria erros. Depois que o agente ja joga bem, variacao ajuda contra detetives especializados.

## 12. Armadilhas de implementacao

- Arestas do grafo devem ser tratadas como bidirecionais, porque `validar(move/2)` aceita `conectado(A,B)` ou `conectado(B,A)`.
- O ladrao nao escolhe cidade inicial; ela eh sorteada.
- O detetive tambem inicia em cidade sorteada.
- O plano precisa funcionar a partir de qualquer cidade inicial.
- `roubar/1` falha se requisitos nao estao todos em `ItensColetados`.
- Se uma acao for ilegal, o estado nao muda e o turno ainda passa para o outro agente.
- Depois de roubar o tesouro, ainda precisa mover para fora da cidade original do tesouro.
- Se tentar sair de uma cidade fechada, o ladrao eh capturado.
- Eventos de roubo revelam a cidade exata do roubo.
- Quanto mais roubos, mais atributos aparecem.
- `adicionar/1` pode afetar fortemente os primeiros atributos revelados porque insere no inicio da aparencia.

## 13. Metrica para comparar estrategias

Ao testar agentes, registre:

- taxa de vitoria contra cada tipo de detetive;
- turnos ate a vitoria;
- numero de roubos realizados;
- numero de atributos reais revelados;
- se houve captura por mandato ou por cidade fechada;
- tesouro escolhido;
- identidade escolhida;
- quantidade de disfarces usados.

Essas metricas ajudam a diferenciar problemas:

- perde por tempo: rota longa demais.
- perde por mandato: pistas muito informativas ou disfarce ruim.
- perde por bloqueio: rota previsivel ou gargalos ignorados.
- empata muito: estrategia segura demais.
- vence so contra detetive simples: falta adversarialidade.

## 14. Estrategia candidata mais promissora

Uma estrategia equilibrada para comecar:

1. No preload, calcular o plano minimo para cada tesouro.
2. Escolher entre os tesouros com menor custo ajustado por:
   - numero de roubos;
   - risco de gargalos;
   - quantidade de alternativas de rota.
3. Escolher o suspeito com maior ambiguidade nos primeiros 2 ou 3 atributos.
4. Durante a partida, seguir o plano, mas recalcular o proximo caminho a partir da cidade atual.
5. Antes de cada roubo, simular a pista revelada.
6. Se a pista permitiria mandato facil, usar disfarce.
7. Depois de roubar o tesouro, sair pela menor rota segura da cidade.

Essa abordagem eh forte porque combina tres necessidades reais do jogo:

- completar o objetivo dentro do limite de turnos;
- reduzir informacao util para o detetive;
- evitar capturas triviais por bloqueio.

Ela ainda eh fraca contra:

- detetives muito especializados no cenario;
- mapas com poucas rotas alternativas;
- estrategias de fechamento que acertem a cidade atual sem depender de pistas;
- limites de turno muito apertados, onde qualquer desvio custa a vitoria.

## 15. Referencias internas no codigo

Arquivos principais para consultar:

- `src/engine/Interactor.prolog`: regras do jogo, validacao de acoes, eventos, vitoria e captura.
- `src/engine/cenario1.prolog`: mapa maior, suspeitos, tesouros, itens e requisitos.
- `src/engine/mapa1.prolog`: mapa pequeno de exemplo.
- `src/engine/agentel.prolog`: exemplo simples de ladrao.
- `src/engine/agented.prolog`: exemplo simples de detetive.
- `src/engine/match_runner.pl`: adaptacao do engine para API, replay e configuracao de cenario.

