# PEAS do agente ladrão

Este PEAS descreve o problema do agente ladrão conforme as regras implementadas em `src/engine/Interactor.prolog`. A estratégia concreta do agente fica separada em `STRATEGY.md`; aqui o foco é definir desempenho, ambiente, atuadores e sensores.

## Resumo

| Componente | Modelagem |
| --- | --- |
| Performance | Vencer roubando o tesouro-alvo e escapando; minimizar turnos, captura, exposição real de pistas e ações sem progresso |
| Environment | Grafo de cidades com itens, tesouros, suspeitos, detetive adversário, cidades fechadas, eventos de roubo e limite de turnos |
| Actuators | `move/2`, `roubar/1`, `disfarce/1`, `despir_disfarce`, `nada` |
| Sensors | Estado do ladrão, cidade atual, itens coletados, aparência, disfarces restantes, eventos, mapa, suspeitos, itens e tesouros |

## P - Performance / Medida de desempenho

O desempenho do agente ladrão deve medir o quanto ele consegue roubar o tesouro-alvo e escapar antes de ser capturado ou antes do limite de turnos.

| Critério | Objetivo |
| --- | --- |
| Vitória | Maximizar vitórias roubando o tesouro-alvo e saindo da cidade onde ele foi roubado |
| Tempo | Minimizar o número de turnos até a vitória |
| Segurança | Minimizar chance de captura por inspeção com mandato ou por tentativa de sair de cidade fechada |
| Discrição | Minimizar pistas reais reveladas cedo |
| Eficiência | Minimizar movimentos e ações sem progresso |
| Robustez | Adaptar-se a diferentes mapas e estratégias de detetive |
| Uso de disfarces | Usar disfarces quando eles atrasam identificação, mandato ou bloqueio |
| Risco de bloqueio | Evitar ficar em cidades fechadas, gargalos e rotas sem alternativa |

Uma função de avaliação possível:

```text
score(estado) =
    + W_vit  * venceu
    - W_turn * turnos_gastos
    - W_pist * atributos_reais_revelados
    - W_risk * (em_gargalo + cidade_recem_revelada + suspeitos_compativeis_menor_igual_2)
    - W_mov  * movimentos_sem_progresso
```

Os pesos `W_*` são ajustáveis. Essa função não precisa ser usada exatamente no código final; ela serve para orientar a heurística. O ponto principal é equilibrar vitória rápida com baixa exposição de identidade e baixo risco espacial.

Precisões importantes do engine:

- Vitória exata: o ladrão vence apenas se `Target` foi registrado em `roubado(Target, CidadeRoubo)`, está em `Itens`, e a cidade atual é diferente de `CidadeRoubo` (`termino/2`, linha 251). Como só o roubo de tesouro executa `assertz(roubado/2)`, roubar apenas itens nunca vence.
- Todo roubo gera evento: `roubar(item)` e `roubar(tesouro)` emitem `roubo(Item, Cidade, Atributos)` (linhas 54-77). Portanto, discrição depende do número total de roubos, não apenas do roubo final.
- Captura por fechamento: se o ladrão tenta executar `move(A,B)` enquanto a cidade atual `A` está fechada, ele é capturado; o engine checa a origem, não o destino (linhas 47-52).
- Mandato do detetive: o detetive pode pedir mandato usando um subconjunto das pistas conhecidas, desde que esse subconjunto reduza os suspeitos compatíveis a no máximo 2 e inclua o suspeito escolhido (linhas 32-38).

## E - Environment / Ambiente

O ambiente é o jogo de perseguição entre ladrão e detetive em um grafo de cidades.

| Elemento | Descrição |
| --- | --- |
| Mapa | Grafo onde os nós são cidades e as arestas são caminhos entre cidades |
| Cidades | Locais onde podem existir itens, tesouros, ladrão e detetive |
| Itens | Objetos intermediários necessários para cumprir requisitos |
| Tesouros | Objetivos finais que o ladrão deseja roubar |
| Suspeitos | Possíveis identidades do ladrão, cada uma com atributos próprios |
| Detetive | Agente adversário que tenta identificar e capturar o ladrão |
| Cidades fechadas | Cidades bloqueadas pelo detetive; se o ladrão tentar sair de uma cidade fechada, perde |
| Eventos de roubo | Informações públicas geradas quando o ladrão rouba item ou tesouro |
| Limite de turnos | Restrição temporal que impede desvios infinitos |

O ambiente é:

| Propriedade | Classificação |
| --- | --- |
| Parcialmente observável | O ladrão não conhece perfeitamente a estratégia ou estado mental do detetive |
| Sequencial | Cada ação afeta decisões futuras |
| Dinâmico | O detetive age entre os turnos do ladrão |
| Discreto | Cidades, ações e turnos são finitos |
| Multiagente | Há pelo menos dois agentes com objetivos opostos |
| Adversarial | O detetive tenta impedir a vitória do ladrão |
| Determinístico nas regras | As ações têm efeitos definidos pelo engine |
| Incerto estrategicamente | A estratégia do detetive é desconhecida |

O ladrão recebe o mapa, suspeitos, itens e tesouros no preload, escolhe sua identidade e seu tesouro-alvo; durante o jogo, seu estado contém cidade atual, identidade, aparência, tesouro-alvo, itens coletados e disfarces restantes.

Mecânicas de ambiente relevantes:

- Requisitos: `roubar/1` só é válido se o item ou tesouro está na cidade atual e todos os seus requisitos já estão nos itens coletados (`validar/3`, linhas 26-27).
- Vazamento por ordem: em cada roubo, o engine revela os primeiros `N` atributos da aparência atual, com `N = min(roubos_anteriores + 1, tamanho_aparencia)` (linhas 60-64 e 73-77).
- Disfarce e ordem: `adicionar(X)` insere `disfarce(X, none)` no começo da aparência, empurrando atributos reais para trás (linha 149). `takeAttr/3` lê a lista da esquerda para a direita (linhas 174-177).
- Custo do disfarce: uma ação `disfarce(Lista)` consome 1 turno e 1 uso de disfarce, mesmo que `Lista` tenha várias mudanças, desde que `length(Lista) =< DisfarcesRestantes` (linhas 28 e 80-83). Logo, agrupar mudanças em uma ação costuma ser melhor que espalhá-las.

## A - Actuators / Atuadores

Os atuadores são as ações que o ladrão pode executar no jogo.

| Ação | Função | Papel estratégico |
| --- | --- | --- |
| `move(Origem, Destino)` | Move o ladrão entre cidades conectadas | Progresso de rota e fuga final; também pode disparar captura se a origem estiver fechada |
| `roubar(ItemOuTesouro)` | Rouba item ou tesouro disponível na cidade atual, se os requisitos forem satisfeitos | Progresso direto de vitória, mas gera evento e pistas |
| `disfarce(ListaDeMudancas)` | Modifica temporariamente a aparência do ladrão | Controle de informação e atraso de mandato |
| `despir_disfarce` | Remove disfarces e restaura a aparência original | Ação secundária, raramente útil porque custa turno |
| `nada` | Passa o turno sem agir | Ação de espera; normalmente ruim para o ladrão |

No contexto estratégico, `roubar/1` e `move/2` são os únicos atuadores que geram progresso direto até a vitória. `disfarce/1` manipula a informação revelada; `despir_disfarce` e `nada` tendem a ser ações de tempo/informação, não de objetivo.

## S - Sensors / Sensores

Os sensores são as informações que o ladrão recebe ou consegue inferir.

| Informação | Uso estratégico |
| --- | --- |
| Cidade atual | Saber de onde planejar o próximo movimento |
| Itens coletados | Saber quais requisitos já foram cumpridos |
| Tesouro-alvo | Saber qual plano seguir |
| Disfarces restantes | Decidir se ainda pode manipular pistas |
| Aparência atual | Simular quais atributos serão revelados em roubos |
| Eventos | Acompanhar os roubos já realizados e inferir quanta informação foi revelada |
| Mapa | Planejar rotas, detectar gargalos e caminhos alternativos |
| Lista de itens e tesouros | Planejar dependências |
| Lista de suspeitos | Escolher identidade ambígua e avaliar risco de mandato |

O ladrão não observa diretamente tudo que seria útil. Em particular, ele não vê a hipótese interna do detetive, e os eventos recebidos no fluxo do jogo são eventos de roubo, não avisos diretos de fechamento ou de interpretação do detetive. Além disso, `disfarce/1` não emite evento público. Isso justifica uma política robusta: evitar planos que só funcionam se o ladrão prever exatamente o próximo passo do detetive.

## Validação experimental

A eficácia do agente deve ser medida em partidas contra detetives de teste variados: perseguidores, bloqueadores, detetives baseados em pistas e detetives conservadores.