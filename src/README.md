# Servidor

O servidor Prolog fica em `src/main.pl` e le a configuracao de `src/config.pl`.

## Configuracao inicial

Antes de rodar o servidor, crie `src/config.pl` a partir do exemplo:

```sh
cp src/config.example.pl src/config.pl
```

Para desenvolvimento local, a configuracao padrao ja usa:

- porta `8080`;
- SQLite em `./data/agents.db`;
- envio de email em modo `console`;
- cenario `mapa1`.

Edite `src/config.pl` se quiser trocar porta, banco, cenario da engine ou
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

## Testar

Smoke test de carregamento das rotas/API sem subir o servidor HTTP:

```sh
swipl -q -g "['src/http/routes/index.pl','src/http/routes/login.pl','src/http/routes/signup.pl','src/http/routes/agents_list.pl','src/http/routes/agents_new.pl','src/http/routes/matches_list.pl','src/http/routes/matches_new.pl','src/http/routes/matches_show.pl','src/http/routes/users_show.pl','src/http/routes/api/health.pl'], halt."
```

Com o servidor rodando, teste a API de health:

```sh
curl http://localhost:8080/api/health
```

Tambem da para validar que o arquivo principal carrega com:

```sh
swipl -q -t halt -s src/main.pl
```

Esse ultimo comando tenta executar a inicializacao do servidor; se o ambiente
bloquear abertura de socket, use o smoke test de rotas acima.
