# Plataforma Web de Agentes Prolog - Detetive & Ladrão

**Discente:** Lucas dos Anjos Camelo - CSI606-2026-01

Plataforma Web para submissão e execução de agentes Prolog que disputam partidas de turnos no estilo "detetive e ladrão" (inspirado em *Scotland Yard*). Usuários se cadastram, enviam agentes, criam partidas entre eles e acompanham os resultados, através de uma interface Web e de uma API HTTP servidas por um backend em SWI-Prolog com persistência em SQLite.

[![Assista no YouTube](https://img.youtube.com/vi/t8u9XmyGOkw/hqdefault.jpg)](https://youtu.be/t8u9XmyGOkw)
https://youtu.be/t8u9XmyGOkw

## Documentação

- **[proposal.md](proposal.md)** - Proposta de trabalho final: tema, escopo, restrições, protótipo e referências.
- **[final-version.md](final-version.md)** - Resultados: tecnologias, funcionalidades implementadas, desafios e instruções de execução.

## Execução rápida

Instruções completas em [src/README.md](src/README.md).

```sh
cp src/config.example.pl src/config.pl
swipl -p pack=./packs -g main_foreground src/main.pl
```

O servidor sobe em `http://localhost:8080`.

## Créditos

O [motor do jogo](src/engine/Interactor.prolog) foi disponibilizado pelo professor [Elton Maximo Cardoso](src/engine/README.md), do DECSI/ICEA/UFOP.
