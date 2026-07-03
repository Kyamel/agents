---
title: "Agente Ladrão Raffles"
subtitle: "Arquitetura e Estratégia"
author:
  - "Mayker Anselmo Brito Lellis — Matrícula: 22.2.8008"
  - "Lucas dos Anjos Camelo — Matrícula: 22.2.8002"
lang: pt-BR
toc-title: "Sumário"
---

# Visão geral

O objetivo do **Ladrão Raffles** é escolher um tesouro, coletar seus pré-requisitos e fugir da cidade final antes que o detetive consiga bloqueá-lo ou capturá-lo.

A estratégia foi construída para funcionar em mapas desconhecidos. O agente não verifica nomes de mapas, cidades, itens, tesouros ou detetives. Todas as decisões são tomadas usando informações estruturais recebidas no início da partida:

- dependências entre itens e tesouros;
- distâncias e caminhos do grafo;
- grau das cidades;
- aparência dos suspeitos;
- inventário atual;
- cidades que diferentes estratégias de detetive provavelmente bloqueariam.

Em termos gerais, o agente tenta manter o plano curto, mas evita ser previsível. Para isso, combina escolha inteligente de identidade, disfarce, cobertura de objetivo, diversificação da coleta, rotas evasivas e previsão de bloqueios.

# Arquitetura do agente

O agente possui duas funções principais.

## Preparação da partida

`ladrao_preload/7` é executado uma vez antes do primeiro turno. Nessa etapa,
o agente:

1. memoriza o mapa, os itens, os tesouros e os suspeitos;
2. escolhe sua identidade;
3. escolhe o tesouro real;
4. procura um tesouro secundário para servir como cobertura;
5. prepara os planos de disfarce;
6. configura uma possível isca;
7. inicializa a memória de rotas e bloqueios.

## Decisão por turno

`ladrao_action/3` é executado a cada turno. A decisão passa por cinco
etapas:

1. atualizar a memória quando um novo roubo for detectado;
2. escolher uma ação básica;
3. verificar se outro objetivo equivalente é menos previsível;
4. adaptar o próximo movimento para evitar riscos;
5. avançar a previsão temporal dos bloqueios.

Essa separação permite que o agente altere sua rota sem comprometer a cadeia de requisitos necessária para vencer.

# Escolha do tesouro

Antes da partida, o agente analisa todos os tesouros cuja cadeia de pré-requisitos pode ser resolvida.

Para cada tesouro, ele expande recursivamente todos os itens necessários, remove repetições e conta o tamanho da cadeia. O tesouro escolhido é um dos que possuem a menor quantidade de requisitos.

Essa escolha reduz:

- o número de roubos;
- a quantidade de pistas reveladas;
- o tempo de exposição no mapa;
- as oportunidades do detetive para bloquear cidades.

Quando dois ou mais tesouros possuem o mesmo custo, o agente escolhe aleatoriamente entre eles. Assim, ele não repete sempre o mesmo objetivo.

# Escolha da identidade

O agente escolhe a identidade que mantém o maior número possível de suspeitos compatíveis durante a revelação das primeiras pistas.

Cada prefixo da aparência é avaliado separadamente. As primeiras posições recebem pesos maiores:

| Posição da pista | Peso |
|---:|---:|
| Primeira | 10000 |
| Segunda | 3000 |
| Terceira | 1000 |
| Quarta | 300 |
| Demais | 100 |

Isso significa que uma identidade ambígua já na primeira pista é muito mais valiosa que uma identidade que só se torna ambígua nas pistas finais.

O objetivo é atrasar a identificação correta e dificultar a emissão de um mandado contra o ladrão real.

# Estratégia de disfarce

O disfarce é aplicado antes do primeiro roubo, para que as primeiras pistas já apresentem uma aparência falsa ou ambígua.

## Disfarce forte

O agente compara sua aparência com a de todos os outros suspeitos e cria planos para imitar os primeiros atributos de outra identidade.

Um plano pode:

- trocar um atributo por outro do mesmo tipo;
- omitir um atributo que não pode ser substituído corretamente.

Os planos são simulados antes da partida. A pontuação considera:

- quantos suspeitos continuam compatíveis;
- se o ID real deixa de ser compatível com as pistas;
- o tamanho do prefixo imitado;
- o número de modificações;
- a quantidade de omissões.

O melhor plano que couber nos pontos de disfarce disponíveis é aplicado.

## Disfarce simples

Se nenhum plano forte puder ser usado, o agente aplica uma única modificação.

Ele testa trocas nos três primeiros atributos e escolhe aquela que mais confunde a identificação. Se nenhuma troca for possível, omite o primeiro atributo.

# Cobertura de objetivo

Depois de escolher o tesouro real, o agente procura um segundo tesouro com uma cadeia de requisitos semelhante e de baixo custo adicional.

Ele coleta os requisitos desse tesouro secundário, mas não rouba o tesouro de cobertura. Em seguida, volta para a cadeia do objetivo real.

O efeito é tornar o histórico de roubos compatível com dois possíveis tesouros. Um detetive que tenta deduzir a cidade final apenas pelos itens roubados pode proteger o objetivo errado.

A cobertura só é escolhida quando seu custo é aceitável para o tamanho do mapa. O agente prioriza a alternativa que acrescenta menos itens à cadeia real.

Quando todos os requisitos da cobertura estão prontos, a cidade desse tesouro passa a ser considerada perigosa. O agente evita entrar nela, pois é um local provável de bloqueio.

# Estratégia de isca

A isca é usada somente quando nenhuma cobertura completa é viável.

O agente seleciona uma cadeia secundária curta e pode roubar no máximo um item que não pertence ao objetivo real.

Uma isca só é aceita quando:

- ainda não foi usada;
- o tesouro real ainda não está pronto;
- o item secundário está disponível;
- o desvio total é de no máximo dois passos.

Essa limitação impede que a tentativa de enganar o detetive atrase demais o plano principal.

# Resolução da cadeia de requisitos

O agente trata itens e tesouros como uma árvore de dependências.

Se um item necessário também possui pré-requisitos, o agente continua descendo pela cadeia até encontrar uma folha que já pode ser roubada.

Exemplo:

```text
Tesouro
├── Chave
│   └── Mini-chave
└── Código
```

Nesse caso, a ordem natural é:

1. roubar a mini-chave;
2. roubar a chave;
3. roubar o código;
4. roubar o tesouro.

O agente só executa um roubo quando todos os requisitos daquele objeto já estão no inventário.

# Diversificação da coleta

Seguir sempre a ordem original dos requisitos torna o caminho previsível. Por isso, o agente procura outras folhas da cadeia que já estejam
disponíveis.

Uma alternativa pode ser escolhida quando:

- pertence ao plano atual;
- ainda não foi roubada;
- está em uma cidade diferente;
- não está mais distante que o objetivo canônico.

Entre as melhores alternativas, a escolha é aleatória.

Depois de escolher uma cidade, o agente mantém essa decisão até que o inventário mude. Isso evita que a randomização provoque movimentos de
zigue-zague.

# Previsão de bloqueios

O agente não identifica a estratégia exata do detetive. Em vez disso, reúne cidades perigosas que representam diferentes comportamentos possíveis.

O conjunto de risco pode conter:

| Risco | Motivo |
|---|---|
| Cidade do último roubo | Um detetive reativo pode bloqueá-la imediatamente. |
| Vizinho previsto | Algumas estratégias bloqueiam os vizinhos do roubo em sequência. |
| Armadilha gulosa | Um perseguidor pode proteger o próximo objeto mais provável. |
| Cidade da cobertura | O detetive pode acreditar que o tesouro secundário é o objetivo real. |

Após cada roubo, os vizinhos da cidade são organizados em uma fila. A cada turno, o agente considera o próximo vizinho como possível bloqueio.

Além disso, ele estima qual objeto disponível parece mais atraente para um detetive que utiliza menor caminho e quantidade de dependências. O primeiro passo em direção a esse objeto é tratado como uma armadilha provável.

# Escolha do movimento

Quando precisa se deslocar, o agente utiliza esta ordem de prioridade:

1. buscar um caminho que evite todas as cidades consideradas perigosas;
2. seguir uma rota evasiva preparada após o último roubo;
3. escolher outro primeiro passo que mantenha a distância mínima;
4. usar o caminho mínimo canônico como fallback.

Ao escolher entre caminhos mínimos, ele prefere:

1. não usar o passo canônico e não retornar à cidade anterior;
2. não usar o passo canônico;
3. não retornar;
4. aceitar qualquer vizinho que aproxime do objetivo.

Essa ordem mantém o progresso até o destino sem repetir sempre a mesma aresta.

# Rota anti-menor-caminho

Depois de cada roubo, o agente calcula o menor caminho até o próximo objetivo. Essa é a rota que um detetive também poderia prever.

Em seguida, tenta encontrar uma rota curta que evite os primeiros vértices internos desse caminho.

As tentativas são:

| Vértices iniciais evitados | Aumento máximo permitido |
|---:|---:|
| Até 3 | 3 passos |
| Até 2 | 2 passos |
| Até 1 | 1 passo |

A rota alternativa só é usada quando:

- é diferente da rota original;
- não aumenta excessivamente o percurso;
- continua levando ao mesmo objetivo.

Os vizinhos são embaralhados durante a busca evasiva. Dessa maneira, seeds diferentes podem produzir rotas diferentes sem abandonar o planejamento.

# Fuga depois do tesouro

Depois de roubar o tesouro real, o único objetivo passa a ser sair da cidade final.

O agente tenta escolher uma saída:

1. diferente da aresta canônica;
2. diferente da cidade de onde acabou de chegar;
3. que não termine em uma cidade-folha;
4. aleatória entre as opções de mesma prioridade.

Quando essas condições não podem ser satisfeitas, qualquer vizinho válido é usado como fallback.

# Ordem de decisão a cada turno

As estratégias são combinadas nesta ordem:

| Prioridade | Decisão |
|---:|---|
| 1 | Aplicar o disfarce forte, quando disponível. |
| 2 | Fugir, caso o tesouro real já tenha sido roubado. |
| 3 | Aplicar o disfarce simples como fallback. |
| 4 | Roubar o tesouro real, se estiver acessível. |
| 5 | Roubar ou caminhar até uma isca válida. |
| 6 | Roubar a próxima folha disponível da cadeia. |
| 7 | Caminhar até o próximo requisito. |
| 8 | Retornar `nada` se nenhuma ação for possível. |

Depois da decisão básica, somente ações de movimento são refinadas pelos mecanismos de diversificação e evasão.

# Resumo da estratégia

O **Ladrão Raffles** tenta vencer com uma cadeia curta, mas acrescenta ambiguidade suficiente para dificultar a previsão do detetive:

- escolhe identidade e disfarce para confundir as primeiras pistas;
- escolhe um tesouro com poucos requisitos;
- prepara cobertura ou uma isca barata;
- alterna entre objetivos equivalentes;
- prevê cidades que podem ser bloqueadas;
- evita o começo do menor caminho óbvio;
- randomiza decisões empatadas;
- escolhe uma saída pouco previsível depois do roubo final.

Em uma frase: **o agente reduz o custo do plano principal e usa diversificação controlada para esconder sua identidade, seu objetivo e sua rota.**
