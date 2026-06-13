# Ferramentas

Este diretorio concentra scripts auxiliares para avaliar agentes e analisar os
resultados.

## Rodar baterias de partidas

Use `tools/eval/run.py` para comparar ladroes e detetives em um cenario.

Exemplo:

```sh
python3 tools/eval/run.py \
  -n 50 \
  -t agents/thief.pl agents/thiefnew.pl \
  -d agents/randomd.pl agents/warrantd.pl agents/neighborblockd.pl \
  --scenario src/engine/cenario1.prolog
```

Opcoes principais:

- `-n`: numero de partidas por combinacao ladrao/detetive.
- `-t`: um ou mais agentes ladroes.
- `-d`: um ou mais agentes detetives.
- `--scenario`: arquivo `.prolog` do cenario.
- `--seed-start`: primeira seed da bateria.

Os resultados sao salvos em uma nova pasta dentro de:

```text
tools/eval/results/
```

Cada pasta contem:

- `matches.csv`: uma linha por partida.
- `summary.csv`: medias e taxas agregadas.
- `best_worst.csv`: melhor e pior partida por combinacao.
- `raw/`: saida bruta de cada execucao.

## Gerar graficos

Use `tools/eval/plot.py` para gerar os PNGs de uma pasta de resultados:

```sh
python3 tools/eval/plot.py tools/eval/results/<pasta-gerada>
```

Os graficos sao salvos em:

```text
tools/eval/results/<pasta-gerada>/figs/
```

## Notebook

Tambem existe `tools/eval/plot.ipynb` para analise grafica interativa.

O notebook importa diretamente as funcoes de `tools/eval/plot.py`, entao ele
gera os mesmos graficos do script sem duplicar a logica. Use o notebook quando
quiser ver os graficos renderizados perto das celulas de analise.

## Gerar cenarios grandes

Para regenerar os cenarios `metro_3_3.prolog` ate `metro_3_7.prolog`:

```sh
python3 tools/generate_scenarios.py
```
