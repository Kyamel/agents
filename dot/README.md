# Parser

Lucas dos Anjos Camelo 22.2.8002
Mayke Anselmo Brito Lellis 22.2.8008

Este programa lê um arquivo de log gerado pela engine do jogo Detetive x Ladrão e gera um arquivo `.dot` compatível com Graphviz.

## Arquitetura

A solução foi dividida em quatro partes principais:

1. **Parser genérico (combinador de parsers)**

   O programa trata o problema como uma pequena gramática. A base é um tipo de parser genérico:

   ```haskell
   newtype Parser a = Parser (String -> Either String (a, String))
   ```

   Um parser consome parte da entrada e devolve `Either`:

   - `Left erro`: não conseguiu ler;
   - `Right (valor, resto)`: leu `valor` e sobrou `resto` para o próximo parser.

   `Parser` é instância de `Functor`, `Applicative` e `Monad`, o que permite encadear parsers em blocos `do`, o encadeamento propaga o `resto` automaticamente e para no primeiro `Left`.

   A partir dessas instâncias, construímos um vocabulário de combinadores reutilizáveis:

   - **primitivos:** `anyChar`, `satisfy`, `char`, `digit`, `space`, `identChar`;
   - **tokens:** `string`, `spaces`, `number`, `identifier`;
   - **combinadores:** `(<|>)` (alternativa "ou", com backtracking), `many` (`*`), `many1` (`+`), `optional` (`?`).

2. **Parsers de domínio**

   Com o vocabulário acima, cada formato de linha vira um parser:

   - `moveLine`: lê `255 ladrao: move(origem,destino)[OK]` -> `ParsedMove`;
   - `theftLine`: lê `>>>> Evento roubo(item,cidade,[...])` -> `ParsedTheft`;
   - `lineP = theftLine <|> moveLine`: uma linha é um roubo **ou** um movimento.

   Linhas de outras ações (`disfarce`, `roubar`, ...) simplesmente fazem os parsers falharem e são ignoradas: `parseLine` devolve lista vazia quando `lineP` retorna `Left`. `parseLog` roda `parseLine` em cada linha e acumula os eventos.

3. **Representação dos dados**

   - `Agent`: `Ladrao` ou `Detetive`;
   - `Movement`: um movimento, com agente, turno, origem e destino;
   - `Theft`: um roubo, com cidade e item roubado;
   - `GameGraph`: guarda a lista de movimentos e a lista de roubos.

   O estado é acumulado com `foldl`.

4. **Geração do DOT**

   A função `renderDot` transforma o `GameGraph` em texto no formato DOT.

   O grafo destaca: caminho do ladrão em vermelho, caminho do detetive em azul, cidades onde houve roubo, ponto de início e ponto de fim de cada agente.

## Execução

```bash
runhaskell Parser.hs partida1.log partida1.dot
dot -Tjpeg partida1.dot -o partida1.jpeg
```
