# Servidor

O servidor Prolog fica em `src/main.pl` e lê a configuração de `src/config.pl`.

## Configuracao inicial

Antes de rodar o servidor, crie `src/config.pl` a partir do exemplo:

```sh
cp src/config.example.pl src/config.pl
```

Para desenvolvimento local, a configuração padrão já usa:

- porta `8080`;
- SQLite em `./data/agents.db`;
- envio de email em modo `console`;
- cenario `mapa1`.

Edite `src/config.pl` se quiser trocar porta, banco, cenário da engine ou
transporte de email.

## Rodar o servidor

Modo interativo:

```sh
swipl src/main.pl
```

Modo foreground, bloqueando o processo:

```sh
swipl -g main_foreground src/main.pl
```

Depois acesse:

```text
http://localhost:8080
```
