# Como utilizar o Interactor

O **Interactor** é a interface responsável por carregar o cenário, os agentes do ladrão e do detetive, executar a partida e mostrar as ações realizadas em cada turno.

## Estrutura esperada

O Interactor utiliza três tipos de arquivos:

- **Cenário:** contém as cidades, conexões, suspeitos, itens, tesouros e o número máximo de turnos.
- **Agente ladrão:** deve exportar `ladrao_preload/7` e `ladrao_action/3`.
- **Agente detetive:** deve exportar `detetive_preload/5` e `detetive_action/3`.

## Iniciando uma partida

Após carregar o Interactor, execute:

```prolog
gameStart(Cenario, Disfarces, AgenteLadrao, AgenteDetetive, EstadoInicial, Vencedor).
```

Exemplo:

```prolog
gameStart(
    mapa1,
    3,
    'agents/baittpro.pl',
    'agents/shortestd.pl',
    EstadoInicial,
    Vencedor
).
```

### Parâmetros

- `Cenario`: nome do arquivo de cenário **sem** a extensão `.prolog`.
- `Disfarces`: quantidade de modificações de disfarce disponíveis para o ladrão.
- `AgenteLadrao`: caminho do arquivo do agente ladrão.
- `AgenteDetetive`: caminho do arquivo do agente detetive.
- `EstadoInicial`: variável que recebe o estado inicial da partida.
- `Vencedor`: variável que recebe o resultado final.

Os possíveis resultados são:

```prolog
Vencedor = ladrao.
Vencedor = detetive.
Vencedor = empate.
```

## Acompanhando a partida

Durante a execução, o terminal exibe as ações realizadas:

```text
255 ladrao: move(city1,city2)[OK]
255 detetive: fechar(city3)[OK]
254 ladrao: roubar(chave)[OK]
```

Cada linha informa:

1. turnos restantes;
2. agente que realizou a ação;
3. ação escolhida;
4. resultado da validação.

`[OK]` indica uma ação válida.  
`[Ilegal]` indica que a ação não foi aceita pela engine e o estado permaneceu inalterado.

Os roubos também geram eventos:

```text
>>>> Evento roubo(chave,city2,[altura(media)])
```

Esses eventos são enviados aos agentes e podem ser usados pelo detetive para atualizar suas pistas.