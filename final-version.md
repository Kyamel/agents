# CSI606-2026-01 - Remoto - Trabalho Final - Resultados

**Discente:** Lucas dos Anjos Camelo

## Resumo

O backend foi construído inteiramente em **SWI-Prolog**, servindo tanto as páginas HTML quanto a API REST, com persistência em **SQLite**. Cada partida é executada de forma **isolada em um subprocesso próprio**, orquestrado por uma fila com pool de workers, de modo que a requisição HTTP nunca bloqueia e o estado global da engine não vaza de uma partida para outra. A proposta original (ver [proposal.md](proposal.md)) foi integralmente atendida e ainda estendida com funcionalidades adicionais, como a visualização das partidas em forma de grafo.

## 1. Tecnologias utilizadas - Backend e Frontend

**Backend**

- **SWI-Prolog** - linguagem e runtime de todo o servidor.
- **Bibliotecas HTTP do SWI-Prolog** (`library(http/...)`) - servidor HTTP, roteamento, tratamento de requisições, sessões e JSON.
- **SQLite** via pacote **`prosqlite`** - persistência de usuários, sessões, verificações de e-mail, agentes e partidas.
- **`library(crypto)`** - hash de senhas e geração/hash de tokens (verificação de e-mail e sessões).
- **`library(process)`** - execução de cada partida em um subprocesso `swipl` isolado.
- **Resend** (com transporte alternativo em `console` para desenvolvimento) - envio dos e-mails de verificação.
- **Engine do jogo** (`src/engine/Interactor.prolog`), disponibilizada pelo professor Elton Maximo Cardoso (DECSI/ICEA/UFOP).

**Frontend**

- **DSL de HTML em Prolog** - o próprio backend gera as páginas por meio de uma DSL e um conjunto de componentes reutilizáveis (`page`, `ui`, `agent_card`, `match_card`, `form_field`, `alert`, `pagination`, etc.).
- **Tailwind CSS via CDN** - estilização das páginas.

## 2. Funcionalidades implementadas

Todo o escopo previsto na proposta foi implementado:

- **Cadastro e autenticação de usuários**, com sessões e hash de senha.
- **Verificação de e-mail** por token, liberando o envio de agentes apenas após confirmação.
- **Upload de agentes em Prolog**, com armazenamento do código-fonte.
- **Validação de segurança do código enviado** (sandbox), bloqueando diretivas e predicados perigosos como `initialization(`, `open(`, `process_create(`, `shell(` e `consult(`.
- **Listagem de agentes** cadastrados e **visualização do código-fonte** de cada agente.
- **Criação de partidas** entre dois agentes (papéis de ladrão e detetive).
- **Execução das partidas em turnos**, com limite de tempo/inferências, em subprocessos isolados.
- **Registro e consulta dos resultados** das partidas.
- **Interface Web** servida pelo próprio servidor Prolog (DSL de HTML + Tailwind via CDN).
- **Persistência em SQLite** de usuários, sessões, verificações, agentes e partidas.

## 3. Funcionalidades previstas e não implementadas

O escopo proposto foi entregue por completo. Mantiveram-se de fora apenas os itens que já haviam sido declarados como **restrições** na proposta (fora do escopo desde o início):

- Sistema avançado de ranking ou *matchmaking* automático.
- Envio assíncrono de e-mails por fila.
- Deploy em produção com domínio próprio e HTTPS obrigatório.
- Estratégia de backup do banco de dados.

## 4. Outras funcionalidades implementadas

Além do escopo previsto, foram implementados:

- **API REST/JSON** completa, paralela à interface Web (endpoints de autenticação, agentes, partidas, usuários, *jobs*, mapa e *health check*).
- **Fila de execução com pool de workers** e **isolamento por subprocesso**: cada partida roda em um `swipl` próprio, evitando bloqueio do servidor e vazamento de estado global entre partidas.
- **Acompanhamento assíncrono das partidas** por meio de *jobs* (listagem e consulta de status de execução).
- **Replay de partidas** a partir do log de execução.
- **Rate limiting** e **controle de escopos/autorização** nas rotas.
- **Registro de acesso** (*access log*).
- **Páginas auxiliares** de *about*, documentação e slides, além de um servidor de documentação (`pldoc`).
- **Exclusão de agentes** pelo próprio dono.
- **Vizualização de Partida**: Realizada no [cliente via JS](assets/match_map.js), exibe gráfico iterativo turno a turno do percurso e ações dos agentes.

## 5. Principais desafios e dificuldades

- **Isolamento da execução dos agentes:** garantir que o código enviado por usuários não comprometesse o servidor exigiu a combinação de validação estática (sandbox por bloqueio de predicados) com execução em subprocessos separados, já que a engine mantém estado global.
- **Desacoplar a execução da requisição HTTP:** partidas podem ser demoradas, então foi necessário construir uma fila com pool de workers para não bloquear o servidor.
- **Gerar HTML a partir de Prolog:** montar uma DSL de componentes reutilizáveis para produzir as páginas sem um framework de frontend tradicional.
- **Integração com o SQLite via `prosqlite`** e organização da camada de acesso a dados (repositórios) em Prolog.
- **Parsing dos logs da engine** para gerar a visualização em grafo, resolvido com um combinador de parsers em Haskell.

## 6. Instruções para instalação e execução

As instruções completas estão em [src/README.md](src/README.md). Em resumo:

**Dependências**

```sh
sudo apt install swi-prolog sqlite3 libsqlite3-dev
```

Instale o pacote `prosqlite` dentro do SWI-Prolog (em `./packs`, para manter no projeto):

```prolog
?- pack_install(prosqlite, [pack_directory('./packs')]).
```

**Configuração**

```sh
cp src/config.example.pl src/config.pl
```

A configuração padrão de desenvolvimento usa porta `8080`, SQLite em `./data/agents.db`, e-mail em modo `console` e cenário `mapa1`.

**Executar o servidor**

```sh
swipl -p pack=./packs -g main_foreground src/main.pl
```

O servidor sobe em `http://localhost:8080`. É necessário estar conectado à internet para o carregamento do Tailwind via CDN.

**Visualização de partidas em grafo (opcional)**

```sh
runhaskell dot/Parser.hs partida1.log partida1.dot
dot -Tjpeg partida1.dot -o partida1.jpeg
```

## 7. Referências

RAVENSBURGER. *Scotland Yard*. Jogo de tabuleiro. Ravensburger, 1983.

WIELEMAKER, Jan et al. *SWI-Prolog*. Disponível em: <https://www.swi-prolog.org/>. Acesso em: 16 maio 2026.

SWI-PROLOG. *HTTP server libraries*. Disponível em: <https://www.swi-prolog.org/pldoc/doc_for?object=section(%27packages/http.html%27)>. Acesso em: 16 maio 2026.

SWI-PROLOG. *Cryptographic password hashes*. Disponível em: <https://www.swi-prolog.org/pldoc/man?section=crypto>. Acesso em: 16 maio 2026.

TAILWIND CSS. *Tailwind CSS Documentation*. Disponível em: <https://tailwindcss.com/docs>. Acesso em: 16 maio 2026.

RESEND. *Resend Documentation*. Disponível em: <https://resend.com/docs>. Acesso em: 16 maio 2026.
