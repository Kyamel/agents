# Análise dos resultados — cenário 1 (engine com delay de 1 turno)

> Reanálise feita após a alteração da engine que **atrasa em 1 turno** a
> publicação do evento de roubo (`src/engine/Interactor.prolog`, commit
> *"corrigir bug da engine revelar a posição do ladrão imediatamente após o
> roubo"*). Os dados vêm de `tools/eval/results/` (7 baterias × 50 partidas,
> `thief.pl` e `thiefnew.pl` contra cada detetive, seed inicial 1, `qdis=3`).
>
> Pesos de score (`run_eval.py`): `vit=1000, turn=10, pist=15, risk=25, mov=5`.
> Score só conta atributos **reais** revelados; atributos de disfarce não pesam.

---

## 1. O que mudou na engine

Antes, `roubar/1` emitia `roubo(Item, Cidade, Attrs)` na hora — o detetive via a
cidade do roubo no **mesmo turno** e fechava exatamente onde o ladrão estava,
matando-o na saída seguinte. Agora o evento fica pendente:

```prolog
atrasarEventoRoubo(E) :- assertz(roubo_pendente(E,2)).
% publicarEventosPendentes/2 roda DEPOIS da ação do ladrão, ANTES do detetive,
% decrementando o contador; o evento só é emitido quando D =< 1.
```

Efeito prático (1 turno de atraso):

```
turno T   ladrão  roubar(X)        -> evento fica pendente, detetive NÃO vê
turno T   detetive ...             -> age sem saber do roubo
turno T-1 ladrão  move(cidade,Y)   -> SAI antes do detetive saber  ← janela de fuga
          (evento publicado aqui)
turno T-1 detetive fechar(cidade)  -> fecha tarde: o ladrão já está em Y
```

**Consequência decisiva:** a fuga final passou a ser viável. Ao roubar o tesouro
e mover no turno seguinte, o ladrão vence *antes* de o detetive descobrir a
cidade. Confirmado em replay (vs `randomd`):

```
17 lad roubar(diamante_azul)   (em h)
17 det liberar(e)
16 lad move(h,j)               -> roubado(diamante,h) e agora em j  => LADRÃO VENCE
```

---

## 2. Resultados atuais (`thiefnew.pl`)

| Detetive | win | turns | roubos | attrs reais | risk | score médio | morte |
|---|---|---|---|---|---|---|---|
| chaserd  | **1.00** | 14.1 | 5.0 | 3.0 | 0.9 | **+554.5** | — vence |
| huntd    | **0.80** | 13.7 | 4.8 | 2.8 | 2.8 | **+378.5** | `closed_city` (nos 20%) |
| randomd  | 0.08 | 9.1 | 3.1 | 1.2 | 1.2 | −151.2 | `closed_city` |
| shortestd| 0.00 | 4.9 | 1.4 | 0.3 | 0.3 | −91.0  | `closed_city` |
| blockerd | 0.00 | 5.5 | 1.8 | 0.1 | 0.1 | −98.8  | `closed_city` |
| guardd   | 0.00 | 11.9 | 4.1 | 2.1 | 2.1 | −339.1 | `inspection` / `closed_city` |
| balancedd| 0.00 | 13.5 | 4.8 | 2.8 | 2.8 | −416.9 | `closed_city` |

### Antes × depois do delay (`thiefnew.pl`)

| Detetive | win antes → depois | turns antes → depois | score antes → depois |
|---|---|---|---|
| huntd     | 0.00 → **0.80** | 10.7 → 13.7 | −292 → **+378** |
| blockerd  | 0.00 → 0.00 | 3.1 → 5.5  | −46 → −99 |
| shortestd | 0.00 → 0.00 | 3.0 → 4.9  | −46 → −91 |
| balancedd | 0.00 → 0.00 | 3.1 → 13.5 | −46 → **−417** |
| guardd    | 0.00 → 0.00 | 11.9 → 11.9 | −339 → −339 |
| chaserd   | 1.00 → 1.00 | 14.1 → 14.1 | +554 → +554 |

Leitura:

- **O delay destravou `huntd`** (de derrota garantida para 80% de vitória) e fez
  o ladrão **sobreviver muito mais** contra os fechadores reativos.
- **Sobreviver mais nem sempre é melhor:** contra `balancedd`/`guardd` o ladrão
  agora arrasta a partida (13 turnos) revelando ~14 atributos reais, o que
  *piora* o score (−46 → −417) sem virar vitória. Penalidade dominada por
  `pist` (15 × attrs) e `turn` (10 × turnos).

### `thief.pl` × `thiefnew.pl`

`thiefnew` **não domina** o ladrão antigo:

| Detetive | thief.pl | thiefnew.pl |
|---|---|---|
| huntd     | **win 1.00 / +514** | win 0.80 / +378 (1 derrota −340) |
| blockerd  | −139 | **−99** |
| balancedd | **−350** | −417 |
| chaserd   | −225 (perde!) | **+554 (vence)** |

`thiefnew` é claramente melhor contra `chaserd` e em sobrevivência vs `blockerd`,
mas a heurística extra **às vezes sai pela culatra** vs `huntd` (20% de derrotas
catastróficas, score −340) e arrasta partidas perdidas vs `balancedd`/`guardd`.

---

## 3. Novo padrão de morte: o ladrão é **cego para locks**

O delay matou a armadilha *reativa* (fechar a cidade do roubo). Sobrou a
armadilha *preventiva*: **o ladrão não enxerga as cidades fechadas** (a engine
não emite evento de `fechar`), então ele **entra numa cidade já fechada e morre
ao tentar sair**. Lembrando a regra de captura ([Interactor.prolog:48-53](src/engine/Interactor.prolog#L48-L53)):
o `move(A,B)` checa se a **origem A** está fechada — entrar numa cidade fechada é
inofensivo, **sair** dela é fatal, e dentro dela *qualquer* movimento mata.

Replay vs `blockerd` (morte por cidade pré-fechada):

```
28 det fechar(a)                 <- fecha 'a' arbitrariamente, cedo
...                              (ladrão coleta itens em f, b, ... usando a janela)
23 lad roubar(senha_banco)       (em 'a' — entrou numa cidade fechada 5 turnos antes)
22 lad move(a,c)                 -> 'a' está fechada => CAPTURADO
```

Replay vs `balancedd` (fecha as 3 cidades de tesouro preventivamente):

```
28 det fechar(j)   |  26 det fechar(h)  |  24 det fechar(i)   (h, i, j fechadas cedo)
22 lad move(f,i)   -> entra em i (ok)
21 lad move(i,g)   -> 'i' fechada => CAPTURADO
```

Como o ladrão **não tem sensor de lock**, ele só pode *inferir* onde estão as
cidades fechadas a partir do comportamento conhecido do detetive.

---

## 4. Classificação dos detetives (com a engine nova)

| Detetive | Regra de fechamento | Situação | Por quê |
|---|---|---|---|
| **chaserd**  | nunca fecha | **vencível (100%)** | só persegue; a janela de fuga basta |
| **huntd**    | só fecha/inspeciona **com mandato** | **vencível (80%, →~100% com disfarce)** | sem mandato vira chaser; as derrotas são por vazar 3 atributos reais |
| **randomd**  | fecha aleatório | **vencível por sorte (8%)** | às vezes não fecha sua rota |
| **shortestd**| fecha o **próximo passo previsto** (rota gulosa) | hard, mas atacável | erra o alvo se o ladrão for imprevisível |
| **blockerd** | fecha cidade de roubo (agora tarde) + fecha **arbitrária** | hard counter | pré-fecha cidades que o ladrão cego acaba pisando |
| **balancedd**| pré-fecha **cidades de tesouro** + roubo + mandato | hard counter | trava a fuga do tesouro independentemente do delay |
| **guardd**   | **acampa as 3 cidades de tesouro** + mandato→inspeção | hard counter | o tesouro-alvo é sempre fechado antes de o ladrão chegar |

**Resumo:** o delay tornou o jogo *ganhável em princípio*, mas
`balancedd`/`guardd`/`blockerd`/`shortestd` continuam difíceis porque fecham
cidades **antes** do roubo (preventivamente), e o ladrão não consegue vê-las.
`balancedd` e `guardd` são praticamente *hard counters* neste mapa: fecham as 3
cidades de tesouro, e a vitória **exige** sair da cidade do tesouro.

---

## 5. Ideias para um ladrão melhor (ordem de retorno)

### 1. Disfarce para negar mandato — maior alavanca, custo ~zero
O ladrão usa **0 disfarces** hoje (`disguises_used = 0` em tudo), com `qdis=3`
disponíveis. O mandato só vale se as pistas reveladas reduzem os suspeitos a ≤2
**e incluem o ID real** ([Interactor.prolog:33-39](src/engine/Interactor.prolog#L33-L39)).
Como `adicionar(X)` prefixa a aparência e `takeAttr` lê da esquerda, prefixar
atributos **falsos (que não pertencem à sua identidade)** faz as pistas reveladas
não casarem com o seu suspeito → **nenhum mandato possível**. Uma ação
`disfarce([adicionar(a1),adicionar(a2),adicionar(a3)])` custa 1 turno/1 uso e
cobre vários roubos. Impacto esperado:
- `huntd`: sem mandato nunca fecha → **0.80 → ~1.00**.
- `guardd`/`balancedd`: remove a morte por `inspection`/mandato.
- **Score:** zera a penalidade `pist` (hoje −15 × ~10–14 atributos = −150 a −210
  por partida nas partidas longas). É o maior ganho de score isolado.

> No replay vs `huntd`, a derrota veio exatamente do 3º atributo real revelado
> (`cor_olhos(escuro)`), que fecha a identificação para o suspeito 9. Disfarce
> impede esse vazamento.

### 2. Roubar o tesouro e fugir na janela do delay
Já funciona vs fechadores reativos. Garantir **sempre sair da cidade do roubo no
turno seguinte** (nunca ficar parado nem roubar dois itens na mesma cidade) para
não desperdiçar a janela de 1 turno.

### 3. Modelar o detetive para inferir locks (vs `shortestd`/`blockerd`)
Como não há sensor de lock, o ladrão deve **simular a regra do detetive**:
`shortestd` fecha o próximo passo do menor caminho previsto → escolher rotas/ordem
de coleta **não-gulosas** desloca o fechamento para a cidade errada. Evitar
revisitar/atravessar cidades que o detetive provavelmente já fechou.

### 4. Escolher o tesouro mais barato e a rota mais curta
`diamante_azul` (h) é o alvo mínimo (5 roubos) vs `coroa_real` (7) e `reliquia`
(8). Menos roubos = menos vazamento, menos turnos, menos pistas. Encerrar a coleta
**vizinho ao tesouro** encurta a exposição final.

### 5. Não arrastar partidas perdidas
Contra `balancedd`/`guardd` (hard counters), sobreviver mais só aumenta as
penalidades `turn`+`pist`+`risk`. Se a vitória é inviável, encurtar a partida
melhora o score relativo. Reduzir `no_progress_moves` e evitar parar em gargalos
(pontos de articulação: `a`, `h`, `i`, `j`…) ataca o `risk` (peso 25, o maior).

---

## 6. Conclusão

- A correção da engine (delay de 1 turno) **destravou a vitória** — visível em
  `huntd` (0% → 80%) e na sobrevivência geral.
- O gargalo agora é **informação**, não rota: o ladrão é cego para locks e morre
  pisando em cidades pré-fechadas. Os detetives que fecham **preventivamente**
  (`balancedd`, `guardd`, `blockerd`, `shortestd`) seguem difíceis.
- O ganho mais barato e imediato é **usar disfarce para negar mandato**, que hoje
  está 100% inexplorado: deve levar `huntd` a ~100%, limpar mortes por inspeção e
  cortar a maior penalidade de score (`pist`).
- `thiefnew.pl` **não domina** `thief.pl`; a "inteligência" extra custa 20% de
  derrotas vs `huntd` e partidas mais longas (e mais penalizadas) vs os hard
  counters — vale revisar essas heurísticas.
