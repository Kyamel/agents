# Detetives

Agentes detetive deste diretorio. Cada um implementa `detetive_preload/5` e
`detetive_action/3` e ataca o ladrao por uma pressao diferente da engine
(trancar cidades, perseguir, deduzir a identidade via mandato). O nome de cada
arquivo indica a estrategia empregada.

Mecanica relevante da engine: o ladrao age antes do detetive no turno; o evento
de um roubo so fica visivel ao detetive 1 rodada depois (delay); `fechar(C)`
mantem `C` trancada ate um novo `fechar` (trava persistente, uma por vez); um
ladrao e capturado ao **sair** de uma cidade trancada, ou por `inspecionar` com
mandato correto na mesma cidade.

## Preditores — deduzem onde trancar

| Agente | Estrategia |
| --- | --- |
| [`route_predictor_d`](route_predictor_d.pl) | Assume ladrao guloso por menor caminho; preve a rota ao objetivo mais proximo e tranca o **primeiro passo** dela. Trava persistente que cai na celula para onde o ladrao ia. |
| [`heist_predictor_d`](heist_predictor_d.pl) | Deduz a cidade do **roubo final**: fecha o tesouro cujos pre-requisitos ja apareceram, quando ele e o **unico** pronto. Depois pede mandato tardio e posicional (confia nas pistas reveladas por ultimo, que o disfarce nao altera). |
| [`belief_predictor_d`](belief_predictor_d.prolog) | Mantem uma crenca do proximo objetivo pela dependencia + itens roubados e tranca a **cidade do item** previsto (nao o passo da rota). |

## Bloqueadores — selam cidades

| Agente | Estrategia |
| --- | --- |
| [`neighbor_blocker_d`](neighbor_blocker_d.pl) | Anti-delay: ao ver um roubo, fecha os **vizinhos** da cidade roubada, 1 por turno, do menor grau ao maior — sela as saidas provaveis. |
| [`robbery_blocker_d`](robbery_blocker_d.pl) | Agressivo: fecha a **cidade do roubo mais recente**; antes do primeiro roubo, tranca qualquer cidade livre. Sempre com uma trava ativa. |
| [`treasure_guard_d`](treasure_guard_d.pl) | Campa e tranca **cidades de tesouro**, forcando o ladrao a sobreviver ao passo de fuga final. |

## Perseguidores — pressao espacial

| Agente | Estrategia |
| --- | --- |
| [`pursuer_d`](pursuer_d.pl) | Caminha em direcao a cidade do ultimo roubo; nao tranca. Captura so por inspecao (mandato + co-localizacao). |
| [`tracker_d`](tracker_d.pl) | Estima a posicao do ladrao (corrige por eventos, projeta um passo); com mandato **fecha a posicao estimada** e inspeciona. Caca posicional + deducao. |
| [`naive_pursuer_d`](naive_pursuer_d.prolog) | Perseguidor de referencia; leitura de eventos ingenua (formato diferente do motor), entao captura pouco. Baseline fraco. |

## Mandato, misto e baseline

| Agente | Estrategia |
| --- | --- |
| [`warrant_hunter_d`](warrant_hunter_d.pl) | Pede mandato assim que as pistas reduzem os suspeitos a <=2; persegue e inspeciona. Neutralizado por identidade ambigua + disfarce. |
| [`balanced_d`](balanced_d.pl) | Misto: mandato cedo + trancar o roubo recente + patrulha a tesouros. Generalista. |
| [`random_d`](random_d.pl) | Acoes aleatorias (baseline de controle). |
| [`stub_d`](stub_d.prolog) | Stub fixo/hardcoded (exemplo de interface); nao generaliza. |

## Avaliar ladroes contra estes detetives

```sh
python3 tools/eval/run.py \
  -n 50 \
  -t agents/allround_bait_t.pl agents/block_model_evader_t.pl \
  -d agents/route_predictor_d.pl agents/heist_predictor_d.pl \
     agents/neighbor_blocker_d.pl agents/robbery_blocker_d.pl \
     agents/tracker_d.pl agents/pursuer_d.pl agents/warrant_hunter_d.pl \
     agents/treasure_guard_d.pl agents/balanced_d.pl \
  --scenario maps/england.prolog
```
