# Estratégia do agente ladrão

Este documento traduz as regras de `src/engine/Interactor.prolog` em decisões práticas para implementar um agente ladrão forte. O PEAS define o problema; aqui entram as heurísticas, prioridades e escolhas de implementação.

## 1. Regras que mandam na estratégia

O ladrão só vence depois de roubar o tesouro-alvo e sair da cidade onde esse tesouro foi roubado. Itens são meios: ajudam a satisfazer requisitos, mas nunca vencem a partida sozinhos. Por isso, todo plano deve terminar com:

1. coletar todos os requisitos do tesouro escolhido;
2. roubar o tesouro;
3. executar um `move(CidadeDoTesouro, Vizinha)` válido.

Todo roubo, de item ou tesouro, publica um evento `roubo(Item, Cidade, Atributos)`. Isso significa que a escolha do tesouro também é escolha de exposição: tesouros com cadeias menores de requisitos tendem a revelar menos atributos e dar menos tempo ao detetive.

O número de atributos revelados cresce com o número de roubos já feitos. No primeiro roubo sai 1 atributo; no segundo, 2; depois 3, e assim por diante, limitado pelo tamanho da aparência. Como o engine pega os atributos do começo da lista, a ordem da aparência é parte central da estratégia.

O detetive pode pedir mandato usando apenas um subconjunto das pistas conhecidas. Se algum subconjunto reduz os suspeitos compatíveis a no máximo 2 e inclui o ladrão real, o risco de captura cresce muito. Pistas falsas que não casam com nenhum suspeito podem ser descartadas por um detetive cuidadoso; elas ajudam mais contra detetives simples do que contra detetives robustos.

Fechamento é perigoso no movimento do ladrão: se ele tenta sair de uma cidade fechada, perde. Como o estado do ladrão não informa diretamente quais cidades estão fechadas, a política deve tratar gargalos e cidades recém-reveladas em eventos como regiões de risco.

## 2. Escolha do tesouro

No `ladrao_preload/7`, avalie cada tesouro por custo composto, não só por distância.

```text
custo_tesouro =
    movimentos_estimados
  + roubos_necessarios * peso_exposicao
  + risco_gargalos_da_rota
  + risco_saida_da_cidade_do_tesouro
```

Um tesouro bom costuma ter:

- poucos requisitos totais, reduzindo eventos e atributos revelados;
- rota curta a partir de várias cidades iniciais possíveis;
- cidade final com pelo menos uma saída simples;
- requisitos distribuídos de modo que permita variar a ordem de coleta;
- baixa dependência de atravessar gargalos depois de revelar eventos.

Evite escolher automaticamente o menor caminho puro. Uma boa política é escolher entre os tesouros com custo próximo ao melhor, por exemplo até 20% ou 30% acima, usando desempate por menor exposição e menor risco de bloqueio. Isso reduz previsibilidade sem transformar variação em desperdício de turnos.

## 3. Planejamento de itens e rota

Modele cada objeto como `objeto(Nome, Cidade, Requisitos)`. Para cada tesouro, expanda recursivamente os requisitos até chegar aos itens sem requisito.

Depois planeje no espaço:

```text
(CidadeAtual, ItensColetados, ObjetosRestantes)
```

Transições úteis:

- mover para uma cidade vizinha;
- roubar objeto disponível na cidade se seus requisitos já estão em `ItensColetados`.

Para cenários pequenos, uma busca em largura ou uma busca de menor custo pode encontrar um plano bom. Para cenários maiores, use heurística gulosa:

1. liste os objetivos atualmente disponíveis;
2. escolha o disponível com menor custo ajustado;
3. caminhe até ele;
4. roube;
5. recalcule.

O custo ajustado do próximo objetivo deve incluir distância, risco da cidade, risco de revelar mais pistas naquele roubo e utilidade do item para liberar outros objetivos.

## 4. Identidade e ambiguidade

Escolha o `ThiefID` pensando nos prefixos da aparência, porque é isso que o engine revela nos primeiros roubos.

Para cada suspeito, calcule:

```text
ambiguidade(ID) =
    soma, para cada prefixo de tamanho N,
    quantidade de suspeitos compatíveis com esse prefixo
```

Quanto maior a ambiguidade dos prefixos iniciais, melhor. O ladrão deve preferir identidades cujo primeiro e segundo atributos ainda mantenham muitos suspeitos possíveis. Se um atributo inicial identifica quase sozinho o ladrão, aquela identidade exige disfarce cedo ou deve ser evitada.

Também vale avaliar ambiguidade contra subconjuntos, porque o mandato não precisa usar todas as pistas. Um conjunto de atributos reais que possui subconjunto muito distintivo é perigoso mesmo que o conjunto completo pareça confuso.

## 5. Disfarces

Uma ação `disfarce(Lista)` consome 1 turno e 1 uso de disfarce, mas pode conter várias mudanças se `length(Lista) =< DisfarcesRestantes`. Portanto, quando for disfarçar, agrupe mudanças que tenham propósito claro.

Prioridades de disfarce:

- antes de roubos que revelariam atributo real distintivo;
- antes de roubos finais, quando `N` já é grande;
- antes de um roubo em cidade que denuncia fortemente o plano;
- quando o próximo evento permitiria mandato com `<= 2` suspeitos compatíveis.

`adicionar(X)` é especialmente forte porque coloca `X` no começo da aparência e empurra atributos reais para trás. Use para controlar os primeiros atributos revelados. `trocar(X,Y)` é útil quando existe um suspeito falso plausível. `omitir(X)` evita revelar um atributo real, mas pode introduzir `none`, que pode ser tratado como pista estranha por detetives melhores.

Não gaste disfarce só por gastar. Se o próximo roubo revela um prefixo ainda ambíguo e o caminho até a vitória é curto, a melhor defesa pode ser velocidade.

## 6. Risco espacial

Como a captura por fechamento acontece ao tentar sair da cidade atual fechada, o ladrão deve reduzir a chance de terminar turno em lugares óbvios para bloqueio.

Penalize cidades que:

- acabaram de aparecer em evento de roubo;
- são gargalos ou pontos de articulação;
- têm poucas saídas;
- ficam no caminho mínimo óbvio entre o roubo recente e o próximo requisito;
- são a cidade do tesouro antes da fuga final.

Gargalos não devem ser proibidos. Às vezes passar por um gargalo cedo economiza muitos turnos. A regra prática é atravessar gargalos antes de revelar eventos importantes, e evitar ficar parado neles depois de roubos.

Depois de roubar o tesouro, a prioridade máxima é sair da cidade do roubo. Se houver várias saídas, escolha uma que não seja cidade recém-revelada, gargalo extremo ou rota óbvia do detetive.

## 7. Função de decisão por turno

Em `ladrao_action/3`, use uma ordem de decisão simples e robusta:

1. Se o tesouro-alvo já está em `ItensColetados`, execute o melhor `move/2` para sair da cidade do roubo.
2. Se há item ou tesouro roubável na cidade atual, avalie o risco informacional do próximo evento.
3. Se o risco informacional é alto e há disfarce restante, execute `disfarce/1`.
4. Caso contrário, execute `roubar/1`.
5. Se não há roubo útil disponível, escolha o próximo objetivo disponível e mova um passo na melhor rota ajustada por risco.
6. Use `nada` apenas como fallback quando nenhuma ação válida melhor existir.

Uma nota de ação pode seguir:

```text
score(acao) =
    + progresso_para_tesouro
    + progresso_para_fuga
    - custo_turno
    - risco_bloqueio
    - risco_mandato
    - exposicao_real
```

O agente não precisa prever perfeitamente o detetive. Ele precisa evitar ações que sejam ruins contra muitos detetives diferentes.

## 8. Detetives de teste

Teste o agente contra perfis variados:

| Perfil | O que ele faz | Resposta do ladrão |
| --- | --- | --- |
| Guloso por pistas | Pede mandato assim que `suspects/2` fica pequeno | Identidade ambígua, disfarce antes de pistas distintivas |
| Bloqueador | Fecha gargalos e cidades reveladas | Rotas alternativas e baixo tempo parado em cidades óbvias |
| Perseguidor | Vai para locais recentes ou próximos objetivos prováveis | Variação controlada de rotas e objetivos |
| Especialista do cenário | Conhece planos mínimos comuns | Escolha mista de tesouro e ordem de coleta |
| Conservador | Demora a agir agressivamente | Rota curta e pouco desperdício com despistes |

A validação deve medir taxa de vitória, turnos até vitória, capturas por fechamento, capturas por inspeção e quantidade de roubos antes do mandato ficar possível.

## 9. Escopo do STRATEGY

Minimax, camadas de arquitetura e modelagem profunda do oponente pertencem aqui, não ao PEAS. Mesmo assim, a primeira versão competitiva provavelmente deve começar com heurísticas simples:

1. escolher tesouro por custo composto;
2. escolher identidade por ambiguidade de prefixos;
3. planejar rota com requisitos;
4. usar disfarce só antes de vazamentos perigosos;
5. recalcular o próximo passo a cada turno.

Essa base já conversa diretamente com o funcionamento real do engine e evita depender de suposições que o estado do ladrão não observa.
