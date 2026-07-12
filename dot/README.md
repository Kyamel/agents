# Gerador de grafo DOT

Este programa lê um arquivo de log gerado pela engine do jogo Detetive x Ladrão e gera um arquivo `.dot` compatível com Graphviz.

## Arquitetura

A solução foi dividida em três partes principais:

1. **Parsing do log**

   A funcao `parseLog` recebe o texto inteiro do arquivo, separa em linhas e usa `parseLine` para identificar apenas os eventos importantes: movimentos validos do ladrão, movimentos validos do detetive, eventos de roubo.

   Linhas com ações inválidas ou ações que não alteram o mapa, como `nada`, são ignoradas.

2. **Representacao dos dados**

   O programa usa tipos simples em Haskell:

   - `Movement`: representa um movimento, com agente, turno, origem e destino;
   - `Theft`: representa um roubo, com cidade e item roubado;
   - `GameGraph`: guarda a lista de movimentos e a lista de roubos.

   O estado e acumulado com `foldl`, sem variaveis globais ou estruturas mutaveis.

3. **Geracao do DOT**

   A funcao `renderDot` transforma o `GameGraph` em texto no formato DOT.

   O grafo destaca: caminho do ladrao em vermelho, caminho do detetive em azul, cidades onde houve roubo, ponto de início e ponto de fim de cada agente.

## Como executar

Entre na raiz do projeto e rode usando `runhaskell`:

```bash
nix-shell --run 'runhaskell dot/Map.hs dot/partida1.log dot/partida1.dot'
```

## Como gerar imagem

Depois de gerar o `.dot`, use o Graphviz:

```bash
dot -Tjpeg dot/partida1.dot -o dot/partida1.jpeg
```