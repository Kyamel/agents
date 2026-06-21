# Servidor

O servidor Prolog fica em `src/main.pl` e lê a configuração de `src/config.pl`.


## Dependências

O servidor usa SWI-Prolog e o pacote `prosqlite` para acessar o banco SQLite.

Instale o SWI-Prolog pelo gerenciador da sua distribuição. Em Debian/Ubuntu:

```sh
sudo apt install swi-prolog sqlite3 libsqlite3-dev
```

Depois instale o pacote `prosqlite` pelo gerenciador de pacotes do próprio SWI-Prolog:

```sh
swipl
```

Dentro do prompt do Prolog:

```prolog
?- pack_install(prosqlite).
```

Ou, para escolher um diretório de instalação dentro do projeto:

```prolog
?- pack_install(prosqlite, [pack_directory('./packs')]).
true.
```

Se você instalou em ./packs, carregue o SWI-Prolog informando esse diretório:

```sh
swipl -p pack=./packs
```

Para testar se a instalação funcionou:

```prolog
?- use_module(library(prosqlite)).
true.
```

Se carregar sem erro, o servidor já deve conseguir usar SQLite.

## Configuração inicial

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
