# Engine

O arquivo [`Interactor.prolog`](Interactor.prolog) foi disponibilizado para uso
neste projeto pelo professor **Elton Maximo Cardoso**
([eltonmc@ufop.edu.br](mailto:eltonmc@ufop.edu.br)), do Departamento de
Computação e Sistemas (DECSI) do Instituto de Ciências Exatas e Aplicadas
(ICEA) da Universidade Federal de Ouro Preto (UFOP).

## Arquitetura

A engine foi organizada em uma fachada pública e módulos com responsabilidades
específicas:

- [`engine.pl`](engine.pl) é a fachada pública de reexporte utilizada pelo restante do servidor.
- [`Interactor.prolog`](Interactor.prolog) é o core, contém as regras do jogo, valida as
  ações dos agentes, atualiza o estado e determina o vencedor.
- [`match_runner.pl`](match_runner.pl) localiza e valida cenários, converte seus
  caminhos para o formato esperado pelo Interactor e extrai o grafo usado pela
  interface web.
- [`match_queue.pl`](match_queue.pl) mantém a fila de partidas e o pool de
  workers. Cada partida é executada em um subprocesso SWI-Prolog independente.
- [`match_worker.pl`](match_worker.pl) executa uma única partida, captura a
  saída do Interactor e grava o resultado em JSON.
- [`match_replay.pl`](match_replay.pl) transforma o log textual da partida em
  um replay estruturado para a API e para a interface.
- [`registry.pl`](registry.pl) valida e registra o código-fonte dos agentes.
- [`sandbox.pl`](sandbox.pl) rejeita padrões perigosos no código enviado, análise estática apenas.
- [`agent_cache.pl`](agent_cache.pl) materializa temporariamente em arquivo o
  código armazenado no banco para execução de partidas.

## Uso direto

O principal predicado do Interactor é:

```prolog
gameStart(Cenario, Disfarces, AgenteLadrao, AgenteDetetive, Estado, Vencedor).
```

O caminho do cenário deve ser informado sem a extensão `.prolog`. A partir da
raiz do projeto, uma partida pode ser iniciada diretamente com:

```sh
swipl -q -g "
  consult('src/engine/Interactor.prolog'),
  gameStart(
    'maps/cenario1',
    3,
    'agents/thief.pl',
    'agents/randomd.pl',
    Estado,
    Vencedor
  ),
  writeln(Estado),
  writeln(Vencedor),
  halt.
"
```

Os agentes precisam ser módulos Prolog que exportem a interface correspondente:

```prolog
% Ladrão
ladrao_preload/7
ladrao_action/3

% Detetive
detetive_preload/5
detetive_action/3
```

Também é possível executar diretamente o worker usado pelo servidor:

```sh
swipl -q -g main -t 'halt(1)' src/engine/match_worker.pl -- \
  maps/cenario1 \
  3 \
  agents/thief.pl \
  agents/randomd.pl \
  /tmp/match.json
```

Nesse caso, o resultado estruturado é gravado em `/tmp/match.json`.

## Execução pelo servidor

Ao iniciar a aplicação, `src/main.pl` inicializa o banco, o servidor HTTP e
chama `engine:start_pool/0`. O fluxo de uma partida é:

1. A rota cria uma partida com estado `queued` e chama
   `engine:enqueue_match/4`.
2. `match_queue.pl` coloca o identificador da partida na fila interna.
3. Um worker do pool busca os agentes no banco e marca a partida como
   `running`.
4. `agent_cache.pl` grava o código atual dos agentes em
   `uploads/agents/<id>-<nome>.pl`.
5. A partida é iniciada em um subprocesso pelo `match_worker.pl`.
6. O worker carrega o Interactor, executa `gameStart/6`, captura o log e usa
   `match_replay.pl` para produzir o JSON do replay.
7. `match_queue.pl` respeita o timeout configurado, persiste vencedor e replay
   no banco e remove o arquivo temporário do resultado.

O número máximo de partidas simultâneas, o timeout, o diretório do cache e o
diretório dos resultados temporários são definidos em `src/config.pl`.

## Cache e sandbox

O banco de dados é a fonte oficial do código dos agentes. O cache existe porque
o Interactor carrega os agentes com `use_module/1`, que exige um arquivo no
sistema. O arquivo é sobrescrito antes de cada partida para refletir sempre a
versão armazenada no banco.

Antes do registro, `sandbox.pl` bloqueia padrões como `initialization/1`,
`use_module/1`, `consult/1`, `open/3`, `process_create/3` e `shell/1`. Essa
verificação é uma proteção inicial, não um isolamento completo. O isolamento
principal da execução vem do subprocesso separado, do limite de tempo e da
separação do estado global entre partidas. Ainda sim, não é seguro para
execução pública indiscriminada na internet.
