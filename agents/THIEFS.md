# Ladroes

Agentes ladrao deste diretorio. Cada um implementa `ladrao_preload/7` e
`ladrao_action/3`. O objetivo e roubar o tesouro-alvo e **sair da cidade do
roubo** sem ser capturado, escondendo a identidade (contra mandato) e a rota
(contra bloqueio/perseguicao). O nome de cada arquivo indica a estrategia.

Mecanica relevante da engine: o ladrao age antes do detetive; cada roubo revela
um prefixo crescente da aparencia (vaza pistas), e `disfarce/1` altera os
primeiros atributos; a vitoria exige estar, no turno seguinte ao roubo do alvo,
numa cidade diferente da do roubo. Ver tambem [DETECTIVES.md](DETECTIVES.md).

## Baselines e referencia

| Agente | Estrategia |
| --- | --- |
| [`greedy_t`](greedy_t.pl) | Guloso simples: rouba o que da, anda pelo menor caminho ao proximo objetivo, foge com o alvo. Previsivel. |
| [`route_cost_t`](route_cost_t.pl) | Move-se pelo melhor objetivo via **custo de rota penalizado**, preferindo rotas menos obvias ao menor caminho cru. |
| [`toposort_t`](toposort_t.prolog) | Ordena o roubo por **ordenacao topologica** das dependencias; omite todos os disfarces no 1o turno; foge apos o alvo. |
| [`random_t`](random_t.pl) | Acoes aleatorias (piso de desempenho). |
| [`scripted_t`](scripted_t.prolog) | Sequencia fixa hardcoded de um mapa (exemplo/template). |

## Isca e ambiguidade de identidade/alvo

| Agente | Estrategia |
| --- | --- |
| [`decoy_t`](decoy_t.pl) | Rouba itens de um **tesouro secundario** para confundir o objetivo real; disfarce inicial. |
| [`unpredictable_t`](unpredictable_t.pl) | Isca + politica de rota que evita **confirmar o modelo guloso** do detetive (aceita alvo mais caro, faz desvios de 1 passo). |
| [`ambiguity_bait_t`](ambiguity_bait_t.pl) | Cadeia curta + identidade ambigua + disfarce forte (parece outro suspeito) + isca oportunista + diversificacao de rota. |
| [`allround_bait_t`](allround_bait_t.pl) | **Generalista robusto**: ambiguidade + isca/cobertura + movimento adaptado a um modelo **agnostico** de bloqueios + fuga imprevisivel. Forte numa gama ampla de detetives e mapas. |

## Evasao de bloqueio e predicao de rota

| Agente | Estrategia |
| --- | --- |
| [`worstcase_evader_t`](worstcase_evader_t.pl) | Assume o pior caso (bloqueio de vizinhos por turno) e evita essas cidades; rotas menos obvias. |
| [`cautious_evader_t`](cautious_evader_t.pl) | Anti-bloqueio + **nao rouba sem disfarce suficiente** (sem pistas, sem mandato). |
| [`chaotic_evader_t`](chaotic_evader_t.pl) | Anti-bloqueio com **aleatoriedade deliberada** de rota/objetivo. |
| [`route_lock_evader_t`](route_lock_evader_t.pl) | **Replica a predicao do detetive de rota** e se recusa a pisar na celula que sera trancada, desviando a custo zero. |
| [`adaptive_t`](adaptive_t.pl) | Evasao de rota + **liga/desliga a isca conforme `max_turnos`**: jogo curto isca ligada, jogo longo isca desligada (menos exposicao). |

## Cobertura (ocultar o alvo coletando muito)

| Agente | Estrategia |
| --- | --- |
| [`full_coverage_t`](full_coverage_t.pl) | Rouba quase **todos** os itens (2 reservados) para nao revelar o alvo; ordem anti-obvia; rouba o tesouro no fim. Caro em turnos. |
| [`coverage_detour_t`](coverage_detour_t.pl) | Cobertura ampla + camadas fortes de **desvio anti-predicao** (conectividade, evitar tesouros prontos, anti-minimo). Imprevisivel, porem lento. |

## Especializados nos detetives META

| Agente | Estrategia |
| --- | --- |
| [`treasure_ambiguity_t`](treasure_ambiguity_t.pl) | Mantem **>=2 tesouros prontos** ao roubar o alvo -> o preditor do roubo final perde o candidato unico e nunca fecha. Coleta focada + evasao do detetive de rota. |
| [`block_model_evader_t`](block_model_evader_t.pl) | Ambiguidade de tesouro + **modelo agnostico de bloqueio** (uniao de padroes previstos) com rerroteamento soft e fail-safe. Forte contra a familia de bloqueadores em mapas grandes. |

## Avaliar contra os detetives

```sh
python3 tools/eval/run.py \
  -n 50 \
  -t agents/allround_bait_t.pl agents/block_model_evader_t.pl \
     agents/treasure_ambiguity_t.pl \
  -d agents/route_predictor_d.pl agents/heist_predictor_d.pl \
     agents/neighbor_blocker_d.pl agents/tracker_d.pl \
  --scenario maps/england.prolog
```
