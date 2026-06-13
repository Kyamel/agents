# Detetives de teste

Estes agentes foram criados para testar ladrões contra pressões diferentes da
engine atual, sem alterar `src/engine/Interactor.prolog`.

| Arquivo | Foco | O que testa no ladrão |
| --- | --- | --- |
| `randomd.pl` | Aleatório geral | Baseline com ações variadas |
| `blockerd.pl` | Bloqueio agressivo | Se o ladrão sobrevive a cidades fechadas invisíveis |
| `shortestd.pl` | Predição de menor caminho | Se o ladrão é previsível por BFS/ordem gulosa de coleta |
| `warrantd.pl` | Mandato e pistas | Se a aparência/disfarce evita identificação |
| `chaserd.pl` | Perseguição por eventos | Se o ladrão foge bem após revelar uma cidade |
| `huntd.pl` | Caça com mandato | Se o ladrão escapa de um detetive que continua perseguindo antes de inspecionar |
| `guardd.pl` | Guarda de tesouros | Se o ladrão consegue roubar e sair de cidades finais perigosas |
| `balancedd.pl` | Misto | Pressão combinada de bloqueio, mandato e patrulha |

Exemplo de avaliação:

```sh
python3 tools/eval/run_eval.py \
  -n 50 \
  -t agents/thief.pl agents/thiefnew.pl \
  -d agents/randomd.pl agents/blockerd.pl agents/shortestd.pl agents/warrantd.pl agents/chaserd.pl agents/huntd.pl agents/guardd.pl agents/balancedd.pl \
  --scenario src/engine/cenario1.prolog
```

Depois:

```sh
python3 tools/eval/plot.py tools/eval/results/<pasta-gerada>
```
