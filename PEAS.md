PEAS do agente ladrão
P — Performance / Medida de desempenho

O desempenho do agente ladrão deve medir o quanto ele consegue roubar o tesouro e escapar antes de ser capturado ou antes do limite de turnos.

Uma boa medida de desempenho seria:

Critério	Objetivo
Vitória	Maximizar vitórias roubando o tesouro-alvo e saindo da cidade do tesouro
Tempo	Minimizar o número de turnos até a vitória
Segurança	Minimizar chance de captura pelo detetive
Discrição	Minimizar quantidade de pistas úteis reveladas
Eficiência	Minimizar movimentos desnecessários
Robustez	Adaptar-se a diferentes mapas e estratégias de detetive
Uso de disfarces	Usar disfarces apenas quando eles realmente atrasam a identificação
Risco de bloqueio	Evitar ficar preso em cidades fechadas ou gargalos

Uma função de avaliação possível:

Essa função não precisa ser exatamente usada no código final, mas serve para orientar a estratégia.

E — Environment / Ambiente

O ambiente é o jogo de perseguição entre ladrão e detetive em um grafo de cidades.

Elementos principais:

Elemento	Descrição
Mapa	Grafo onde os nós são cidades e as arestas são caminhos entre cidades
Cidades	Locais onde podem existir itens, tesouros, ladrão e detetive
Itens	Objetos necessários para cumprir requisitos de outros itens ou tesouros
Tesouros	Objetivos finais que o ladrão deseja roubar
Suspeitos	Possíveis identidades do ladrão, cada uma com atributos próprios
Detetive	Agente adversário que tenta identificar e capturar o ladrão
Cidades fechadas	Cidades bloqueadas pelo detetive; se o ladrão tentar sair de uma cidade fechada, perde
Eventos de roubo	Informações geradas quando o ladrão rouba algo
Limite de turnos	Restrição temporal que impede o ladrão de fazer desvios infinitos

O ambiente é:

Propriedade	Classificação
Parcialmente observável	O ladrão não conhece perfeitamente a estratégia ou estado mental do detetive
Sequencial	Cada ação afeta decisões futuras
Dinâmico	O detetive age entre os turnos do ladrão
Discreto	Cidades, ações e turnos são finitos
Multiagente	Há pelo menos dois agentes com objetivos opostos
Adversarial	O detetive tenta impedir a vitória do ladrão
Determinístico nas regras	As ações têm efeitos definidos pelo engine
Incerto estrategicamente	A estratégia do detetive é desconhecida

O ladrão recebe o mapa, suspeitos, itens e tesouros no preload, escolhe sua identidade e seu tesouro-alvo; durante o jogo, seu estado contém cidade atual, identidade, aparência, tesouro-alvo, itens coletados e disfarces restantes.

A — Actuators / Atuadores

Os atuadores são as ações que o ladrão pode executar no jogo.

Ação	Função
move(Origem, Destino)	Move o ladrão entre cidades conectadas
roubar(ItemOuTesouro)	Rouba um item ou tesouro disponível na cidade atual, se os requisitos forem satisfeitos
disfarce(ListaDeMudancas)	Modifica temporariamente a aparência do ladrão
despir_disfarce	Remove disfarces e restaura a aparência original
nada	Passa o turno sem agir

No contexto estratégico, as ações mais importantes são:

Eu consideraria despir_disfarce uma ação secundária, raramente útil, porque custa turno e geralmente não ajuda diretamente a vencer.

S — Sensors / Sensores

Os sensores são as informações que o ladrão recebe ou consegue inferir.

Informação	Uso estratégico
Cidade atual	Saber de onde planejar o próximo movimento
Itens coletados	Saber quais requisitos já foram cumpridos
Tesouro-alvo	Saber qual plano seguir
Disfarces restantes	Decidir se ainda pode manipular pistas
Aparência atual	Simular quais atributos serão revelados em roubos
Eventos	Acompanhar os roubos já realizados e inferir quanta informação foi revelada
Mapa	Planejar rotas, detectar gargalos e caminhos alternativos
Lista de itens e tesouros	Planejar dependências
Lista de suspeitos	Escolher identidade ambígua e avaliar risco de mandato

O ladrão não observa diretamente tudo que seria útil. Por exemplo, ele não necessariamente sabe com precisão qual cidade o detetive fechou ou qual hipótese o detetive está seguindo. Por isso, o agente precisa agir de forma robusta, não depender de saber exatamente o que o detetive está fazendo.

PEAS em forma resumida
Componente	Modelagem
Performance	Vencer roubando o tesouro e escapando; minimizar turnos, risco de captura, exposição de pistas e uso desnecessário de disfarces
Environment	Grafo de cidades com itens, tesouros, suspeitos, detetive adversário, cidades fechadas, eventos de roubo e limite de turnos
Actuators	move/2, roubar/1, disfarce/1, despir_disfarce, nada
Sensors	Estado do ladrão, cidade atual, itens coletados, aparência, disfarces restantes, eventos, mapa, suspeitos, itens e tesouros