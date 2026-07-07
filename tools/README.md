# Ferramentas

Este diretorio concentra scripts auxiliares para avaliar agentes e analisar os
resultados.

## Rodar baterias de partidas

Use `tools/run.py` para comparar ladroes e detetives em um cenario.
O script de linha de comando usa `tools/match_data.py` para fazer parsing,
normalizacao, extracao de metricas e agregacoes dos resultados.

Exemplo:

```sh
python3 tools/run.py \
  -n 50 \
  -t agents/random_t.pl agents/greedy_t.pl \
  -d agents/random_d.pl agents/warrant_hunter_d.pl agents/neighbor_blocker_d.pl \
  --scenario maps/cenario1.prolog
```

Opcoes principais:

- `-n`: numero de partidas por combinacao ladrao/detetive.
- `-t`: um ou mais agentes ladroes.
- `-d`: um ou mais agentes detetives.
- `--scenario`: arquivo `.prolog` do cenario.
- `--seed-start`: primeira seed da bateria.

Os resultados sao salvos em uma nova pasta dentro de:

```text
tools/results/
```

Cada pasta contem:

- `matches.csv`: uma linha por partida.
- `summary.csv`: medias e taxas agregadas.
- `best_worst.csv`: melhor e pior partida por combinacao.
- `raw/`: saida bruta de cada execucao.

## Gerar graficos

Use `tools/plot.py` para gerar os PNGs de uma pasta de resultados:

```sh
python3 tools/plot.py tools/results/<pasta-gerada>
```

Os graficos sao salvos em:

```text
tools/results/<pasta-gerada>/figs/
```

## Notebook

Tambem existe `tools/plot.ipynb` para analise grafica interativa.

O notebook importa diretamente as funcoes de `tools/plot.py`, entao ele
gera os mesmos graficos do script sem duplicar a logica. Use o notebook quando
quiser ver os graficos renderizados perto das celulas de analise.

## Gerar cenarios grandes

Para regenerar os cenarios `metro_3_3.prolog` ate `metro_3_7.prolog`:

```sh
python3 tools/generate_scenarios.py
```
