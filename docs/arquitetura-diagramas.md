---
title: "Scotland Yard em Prolog - Diagramas de Arquitetura"
subtitle: "Material de apoio para o vídeo de apresentação (CSI606)"
author: "Lucas dos Anjos Camelo"
lang: pt-BR
---

# Diagramas da aplicação

> Material de apoio para o vídeo (~10-13 min). Cada seção tem um diagrama Mermaid, um link para o **código a exibir** e um parágrafo do que falar. A ordem segue o roteiro em [`assets/slides/scotland-yard/README.md`](../assets/slides/scotland-yard/README.md).

> [!tip] Como visualizar no Obsidian
> - Abra em **Reading view** (`Ctrl/Cmd+E`).
> - Cada diagrama mora em `docs/diagrams/` e é **embutido** aqui via `![[nome]]` (transclusão). Edite o arquivo do diagrama e ele atualiza automaticamente nesta nota. Para ver/editar um diagrama sozinho, abra o arquivo correspondente.
> - Os embeds só renderizam **dentro do Obsidian**. No GitHub / editor comum eles aparecem como texto `![[...]]` (nesse caso, abra os arquivos em `docs/diagrams/`).
> - Cada diagrama já traz **cores próprias** (tema `base` com linhas roxas), legível no tema claro e escuro. São verticais/estreitos de propósito para não cortar a borda direita; se ainda ficar largo, encolha a fonte (`Ctrl/Cmd -`).

---

## 1. Visão geral - arquitetura em camadas

**Código:** [`src/main.pl`](../src/main.pl) · [`src/server/server.pl`](../src/server/server.pl)

Um único processo **SWI-Prolog** faz tudo: fala HTTP, gera HTML, valida regras, persiste em SQLite e orquestra a execução das partidas. Duas interfaces (Web HTML e API JSON) ficam **sobre os mesmos serviços**, sem duplicar regra de negócio.

![[01-arquitetura-camadas]]

**Fala:** "O servidor é SWI-Prolog puro. A requisição passa por um middleware (CORS, rate limit, sessão/token), chega numa rota que age como *controller*, que chama um serviço com a regra de negócio. O serviço fala com a persistência, a infra de email ou a engine. As *views* geram HTML com uma DSL. Web e API compartilham exatamente os mesmos serviços."

---

## 2. Inicialização (bootstrap)

**Código:** [`src/main.pl`](../src/main.pl) (`ensure_started/0`)

Carregar `src/main.pl` dispara `initialization(main)`, que sobe as camadas em ordem, sob um mutex, de forma idempotente.

![[02-bootstrap]]

**Fala:** "No boot, inicializo o banco e aplico migrações, sincronizo papéis de admin, subo o servidor HTTP e ligo o pool de workers, que já recupera partidas pendentes de uma execução anterior."

---

## 3. Modelo de dados (SQLite)

**Código:** [`src/db/schema.pl`](../src/db/schema.pl) · [`src/db/db.pl`](../src/db/db.pl)

Cinco tabelas. Tokens de verificação de email e de sessão são guardados como **hash SHA-256**, nunca em texto puro. Os relacionamentos são lógicos (a coluna `*_id` referencia a chave da outra tabela).

![[03-modelo-dados]]

Colunas omitidas do diagrama por brevidade: `username`, vários `created_at`, `started_at`, `finished_at`, `error_message`. Valores de `matches.status`: `queued | running | done | error | timeout`.

**Fala:** "O banco tem usuários, verificações de email, sessões, agentes e partidas. Tokens são armazenados como hash. O agente guarda o próprio código-fonte. A partida guarda o ciclo de vida completo, do `queued` até o `replay_json` final, o que permite reconstruir a visualização sem rodar o jogo de novo."

---

## 4. Requisição de página **não autenticada** (HTML público)

**Código:** [`src/server/routes/web/agents_list.pl`](../src/server/routes/web/agents_list.pl) · [`src/server/views/page.pl`](../src/server/views/page.pl)

Páginas como a inicial e as listagens funcionam para qualquer visitante. A sessão é resolvida *best-effort*: com cookie válido a navbar mostra o usuário; senão, `anon`.

![[04-pagina-nao-autenticada]]

**Fala:** "Numa página pública, a rota busca os dados no serviço e manda para `reply_page`, que tenta resolver o usuário logado; se não achar, segue como anônimo e monta a mesma página, mudando só a barra de navegação."

---

## 5. Requisição de página **autenticada** (HTML protegido)

**Código:** [`src/server/http/web_session.pl`](../src/server/http/web_session.pl) · [`src/server/routes/web/agents_new.pl`](../src/server/routes/web/agents_new.pl)

Rotas como *enviar agente* e *nova partida* exigem sessão. `require_user/2` lê o cookie `agents_session`, valida o hash contra `auth_sessions` e, se falhar, lança um redirect `303` para o login.

![[05-pagina-autenticada]]

> Regra extra: mesmo logado, o **envio** de agente só é liberado se `User.is_verified == true` (senão mostra aviso "verifique seu email").

**Fala:** "Nas páginas protegidas, `require_user` checa o cookie de sessão contra o banco. Sem sessão válida, redireciona para o login. E o envio de agente ainda exige o email verificado."

---

## 6. Requisição de **API JSON** (o *recipe* `api_endpoint`)

**Código:** [`src/server/http/api_endpoint.pl`](../src/server/http/api_endpoint.pl) · [`src/server/routes/api/matches_list.pl`](../src/server/routes/api/matches_list.pl)

Todo endpoint em `routes/api/` só declara um contrato (`path`, `accept`, `handle`, `render`). `api_endpoint:mount/1` vira uma rota HTTP e cuida de CORS, rate limit, autenticação por método (`none` ou `bearer`), preflight `OPTIONS` e erros - sem repetir esse encanamento em cada arquivo.

![[06-api-recipe]]

Exemplo real - `POST /api/v1/matches` (exige Bearer) devolve **202 queued**, sem esperar o jogo terminar:

![[06b-api-post-matches]]

**Fala:** "A API é declarativa: cada endpoint só diz seu caminho, quem pode acessar e como responder. Uma infra comum aplica CORS, rate limit e Bearer. Criar partida devolve `202 queued`, não segura a requisição até o jogo acabar."

---

## 7. Cadastro + verificação de email + login

**Código:** [`src/services/accounts.pl`](../src/services/accounts.pl) · [`src/infra/mail.pl`](../src/infra/mail.pl) · [`src/infra/tokens.pl`](../src/infra/tokens.pl)

`accounts.pl` concentra a regra: valida, faz hash da senha com `crypto_password_hash`, gera um token, guarda **só o hash** e envia o link. O transporte de email é plugável: `console` (dev) ou `resend` (produção).

![[07-cadastro-verificacao]]

O **login** emite a sessão que vira cookie `HttpOnly`:

![[07b-login-sessao]]

**Fala:** "No cadastro, a senha vira hash e um token de verificação é gerado; só o hash vai pro banco. Em dev o link aparece no terminal; em produção o Resend envia. Ao clicar no link, a conta é ativada. O login cria uma sessão que vira cookie HttpOnly de 7 dias."

---

## 7.1. Autenticação: cookie vs Bearer (mesma store)

**Código:** [`src/server/routes/api/auth_login.pl`](../src/server/routes/api/auth_login.pl) · [`src/server/http/authz.pl`](../src/server/http/authz.pl) · [`src/server/http/web_session.pl`](../src/server/http/web_session.pl) · [`src/db/auth_repo.pl`](../src/db/auth_repo.pl)

O login web devolve um cookie `HttpOnly`, mas a API JSON também aceita **Bearer token** para clientes que não usam cookies (apps nativos, CLI, `fetch`). São **o mesmo token de sessão**, só com transporte diferente: o browser recebe e reenvia via cookie automaticamente; o app nativo obtém o token no corpo da resposta do login e o reenvia no header `Authorization: Bearer TOKEN`. Ambos caem no mesmo `find_user_id_by_session_token_hash/2`, sobre a mesma tabela `auth_sessions`.

![[07_1-auth-cookie-bearer]]

Obs: o token só aparece **no corpo JSON uma vez**, na *resposta* de `POST /api/v1/auth/login`. Nas requisições autenticadas seguintes ele vai **no header** `Authorization`, nunca no body. A rota web `/login` seta cookie; a rota de API de login **não seta cookie**, devolve o token para o cliente guardar.

| Cliente | Login devolve | Envia nas próximas | Proteção |
|---|---|---|---|
| **Browser (web)** | `Set-Cookie: agents_session=… HttpOnly; SameSite=Lax` | cookie automático | JS não lê o token (XSS); SameSite mitiga CSRF |
| **App nativo / CLI / fetch** | `token` no corpo JSON | header `Authorization: Bearer TOKEN` | o app é dono do token; sem cookie, sem CSRF |

> [!note] Modelo de sessão: opaca e com estado no servidor
> É **um token só** (sessão opaca aleatória), **não** access + refresh e **não** JWT. Cada requisição autenticada faz `sha256(token)` e um `SELECT` em `auth_sessions` (PK `token_hash`) checando *não revogada* e *não expirada*, ou seja, **valida no DB toda vez**. TTL fixo de **7 dias** a partir da emissão (sem refresh, sem sliding expiration; ao expirar, loga de novo). Em troca do custo desse lookup por request, ganha-se **revogação imediata** no logout (`revoked_at`), o que um JWT stateless não dá. Foi uma escolha consciente: simplicidade e revogação na hora, adequadas ao tamanho do projeto, em vez de escala stateless.

**Fala:** "O login web devolve um cookie HttpOnly, que é o certo pro browser, porque o JavaScript nunca toca no token. Mas a API também aceita Bearer token: um app nativo faz o login, recebe o token no corpo da resposta e passa a mandá-lo no header Authorization. É a mesma sessão, a mesma tabela e a mesma validação, só muda o transporte, cookie para o browser e Bearer para quem não tem cookie."

---

## 8. O núcleo: execução **assíncrona** de partidas

**Código:** [`src/services/matches.pl`](../src/services/matches.pl) · [`src/engine/match_queue.pl`](../src/engine/match_queue.pl) · [`src/engine/match_worker.pl`](../src/engine/match_worker.pl) · [`src/engine/sandbox.pl`](../src/engine/sandbox.pl) · [`src/engine/registry.pl`](../src/engine/registry.pl)

A partida pode demorar (ou travar num agente ruim), então **não roda dentro da requisição HTTP**. O serviço só enfileira; um pool de workers executa cada partida num **subprocesso `swipl` isolado**, com timeout, e persiste o resultado.

![[08-nucleo-assincrono]]

Destaques:

- **Isolamento:** cada partida é um processo `swipl` separado -> o estado global da engine não vaza entre partidas e o servidor nunca trava.
- **Concorrência:** o pool tem `max(8, cpu-1)` workers.
- **Timeout:** 6h; ao estourar, mata o subprocesso (TERM, depois KILL).
- **Segurança (parcial):** antes de gravar, `sandbox.pl` rejeita `use_module`, `consult`, `open/3`, `process_create`, `shell`, `initialization`. É análise estática, não isolamento forte; subprocesso + timeout mitigam.

**Fala:** "Criar partida só enfileira e responde na hora. Um worker pega o job, materializa o código dos agentes a partir do banco e roda o jogo num subprocesso separado, com timeout. Vencedor e replay são persistidos no SQLite."

---

## 8.1. Ciclo de vida visto pelo cliente (enfileirar -> polling -> JSON normalizado)

**Código:** [`src/server/routes/api/matches_show.pl`](../src/server/routes/api/matches_show.pl) · [`src/server/routes/api/map_show.pl`](../src/server/routes/api/map_show.pl) · [`src/server/views/match_map_data.pl`](../src/server/views/match_map_data.pl)

Aqui está o mesmo fluxo **do ponto de vista do cliente**, com as **duas (ou três) requisições HTTP separadas**: a 1ª enfileira e recebe `202 queued`; enquanto o worker roda em segundo plano, o cliente faz *polling* de status; quando fica `done`, uma última requisição busca o **JSON já normalizado** (`cities`, `edges`, `frames`...) que o JavaScript interpreta para montar o mapa.

![[08_1-ciclo-cliente]]

> Na **interface web** (`/map/{id}`) esse mesmo JSON normalizado já vem **embutido inline** no HTML (o `DataJson` gerado por `match_map_data:map_data/3`), então a página não precisa da requisição extra, o JS lê o dado já presente e só cuida do layout, do SVG e do playback. O endpoint `GET /api/v1/map/{id}` existe para quem consome a partida **pela API** (ou para recarregar o mapa sob demanda).

Por que **duas requisições** e não uma só que espera a partida?

- A execução pode levar de segundos a horas -> segurar a conexão HTTP aberta seria frágil (timeout de proxy, aba fechada, etc.).
- O `202 queued` devolve na hora um `match_id`; o cliente decide **quando** e **com que frequência** consultar (o front pode até só mostrar a partida concluída depois).
- Estados intermediários (`queued`/`running`, com `elapsed_seconds` via `GET /api/v1/jobs/{id}`) permitem uma UI de progresso sem bloquear nada.

**Fala:** "Do lado do cliente são requisições separadas: a primeira enfileira e recebe na hora um id com estado `queued`. Enquanto o worker roda em segundo plano, o cliente consulta o status. Quando fica `done`, ele busca o replay já normalizado; cidades, arestas e os frames de cada turno; e o JavaScript só monta o mapa a partir desse JSON."

### Contrato do JSON normalizado da partida

Produzido por `match_map_data:map_data/3` e servido em `GET /api/v1/map/{id}` (mesmo objeto embutido inline na página `/map/{id}`). O grafo é lido dos fatos `cidade/1` e `conectado/2` do cenário; o restante é o **estado acumulado turno a turno**, já pronto para o playback (o JS não recalcula regra do jogo).

```jsonc
{
  "cities": ["a", "b", "c", "j"],          // ids de cidade, ordenados
  "edges": [["a","b"], ["b","c"]],          // pares ordenados [Lo,Hi], não-direcionados
  "loot": [                                  // itens e tesouros do cenário
    { "kind": "item",    "name": "bateria",    "city": "d", "requirements": [] },
    { "kind": "tesouro", "name": "coroa_real", "city": "j", "requirements": ["chave_real"] }
  ],
  "objective": {                             // tesouro-alvo do ladrão (ou nulls)
    "name": "coroa_real",
    "city": "j",
    "requirements": ["chave_real", "codigo_cofre"]
  },
  "thiefIdentity": { "id": "3", "name": "sr_black" },  // ou null
  "frames": [ /* 1 frame inicial + 1 por turno - ver abaixo */ ]
}
```

**Cada `frame`** (índice 0 = `"Início"`; demais = um por turno, em ordem crescente):

```jsonc
{
  "label": "Turno 4",
  "t": "e",                 // cidade atual do ladrão (string) ou null
  "d": "b",                 // cidade atual do detetive ou null
  "tPath": ["a","d","e"],   // rota acumulada do ladrão
  "dPath": ["c","b"],       // rota acumulada do detetive
  "blocked": ["g"],         // cidades fechadas (acumula, ou única, conforme lock_mode)
  "objectiveCity": "j",     // cidade do tesouro-alvo
  "objectiveReady": false,  // true quando todos os requisitos já foram coletados
  "robberyCities": ["e"],   // cidades onde houve roubo NESTE turno
  "eventText": "roubo(bateria, e, [alto])",   // events achatados em texto (\n)
  "collected": ["bateria"], // itens coletados (acumulado)
  "revealed": ["alto"],     // atributos revelados por roubos (acumulado)
  "appearance": [           // aparência do ladrão; current=null quando omitido
    { "original": "alto", "current": "alto" },
    { "original": "barba", "current": "sem_barba" }
  ],
  "mandate": null,          // ou objeto de mandato (ver abaixo)
  "events": [ /* timeline estruturada do turno - ver abaixo */ ]
}
```

**`mandate`** (quando o detetive pediu mandato) - `null` até existir:

```jsonc
{ "suspect": "3", "clues": ["alto","barba"], "suspectName": "sr_black" }
```

**`events[]`** - timeline estruturada, discriminada por `type` (o `text` é a versão legível já pronta):

| `type` | `agent` | Campos além de `type`, `agent`, `turn`, `text` |
|---|---|---|
| `"robbery"` | `thief` | `item`, `city`, `revealed[]` |
| `"disguise"` | `thief` | `action` (termo do disfarce aplicado) |
| `"mandate"` | `detective` | `suspect`, `clues[]` |
| `"inspection"` | `detective` | `city`, `mandate` (objeto ou `null`) |

Observações do contrato:

- **Tudo é acumulado**: `tPath`, `dPath`, `blocked`, `collected`, `revealed` e `appearance` já refletem o estado *até* aquele turno, o front só desenha.
- **Ausência vira sentinela**, não erro: cenário inválido -> `cities/edges = []`; sem alvo -> `objective` com `null`; identidade desconhecida -> `thiefIdentity: null`.
- **`appearance[].current = null`** significa atributo omitido por disfarce; `original = null` significa atributo *adicionado* por disfarce.
- Valores como cidade, item e atributo são **strings** (átomos Prolog serializados via `term_text/2`), não termos.

**Fala (contrato):** "O que o JavaScript recebe não é o log cru: é um contrato estável. Um cabeçalho com grafo, itens e objetivo, e uma lista de frames, um por turno, com o estado já acumulado: posições, rotas, cidades bloqueadas, itens coletados, pistas, aparência e mandato. Além de uma timeline de eventos tipada, com um texto legível pronto. Assim o front só apresenta; toda a regra ficou no servidor."

---

## 9. Durabilidade da fila (recuperação após restart)

**Código:** [`src/engine/match_queue.pl`](../src/engine/match_queue.pl) (`recover_pending/0`)

A fila em memória sobrevive a reinícios porque a fonte da verdade é o banco: `recover_pending` no boot reprocessa o que ficou pendente.

![[09-durabilidade-fila]]

**Fala:** "Se o servidor cair, nenhuma partida some: no boot, tudo que estava na fila ou executando é relido do banco e reenfileirado."

---

## 10. Integração com Tailwind (tema como fonte única)

**Código:** [`src/server/views/page.pl`](../src/server/views/page.pl) (`tailwind_config/1`)

Não há build de CSS: `page.pl` injeta o **Tailwind via CDN** e um objeto `window.appTheme` com toda a paleta. Esse mesmo objeto alimenta o `tailwind.config` (classes no HTML) **e** os assets JS do mapa (cores de arestas, nós, roubos, bloqueios). Uma paleta, zero hex duplicado.

![[10-tailwind]]

> Como o Tailwind é **CDN**, é preciso internet durante a gravação, senão a página aparece sem estilo.

**Fala:** "Uso Tailwind por CDN, sem build. A paleta fica num único objeto que serve tanto às classes do HTML quanto às cores do SVG do replay, então não há cor duplicada entre CSS e JavaScript."

---

## 11. Frontend do replay (do JSON persistido aos frames no navegador)

**Código:** [`src/server/views/match_map_page.pl`](../src/server/views/match_map_page.pl) · [`src/server/views/match_map_data.pl`](../src/server/views/match_map_data.pl) · [`assets/match_map.js`](../assets/match_map.js)

O replay é persistido uma vez. Para exibir, o servidor projeta esse JSON em *frames* prontos (`match_map_data.pl`); o navegador só cuida de layout, SVG e playback (play/pause, slider, teclado), com atenção à acessibilidade.

![[11-replay-frontend]]

**Fala:** "O servidor entrega frames prontos; o JavaScript modular calcula o layout do grafo, desenha o SVG e controla o playback turno a turno, com atalhos de teclado e recursos de acessibilidade."

---

## 12. Bibliotecas e para que servem

**Código:** [`src/README.md`](../src/README.md) (dependências) · [`deploy/README.md`](../deploy/README.md) (container/proxy)

Quase tudo vem do próprio ecossistema SWI-Prolog; as únicas peças externas são o SQLite (via prosqlite), o Tailwind (CDN) e o Resend (email).

| Biblioteca / ferramenta | Papel no projeto |
|---|---|
| `http/thread_httpd`, `http_dispatch` | Servidor HTTP multi-thread e roteamento |
| `http/http_cors` | CORS e resposta a `OPTIONS` (preflight) da API |
| `http/html_write` | DSL para gerar HTML no servidor (as *views*) |
| `http/http_json`, `http/json` | Ler corpo JSON e serializar respostas/replay |
| `http/http_parameters` | Ler campos de formulário e query string |
| `http/http_client` | Chamar a API do Resend (email real) |
| `library(crypto)` | `crypto_password_hash` (senha) e SHA-256 (tokens) |
| `library(process)` | Rodar cada partida num subprocesso `swipl` isolado |
| `library(filesex)` | Materializar o código do agente em arquivo (cache) |
| `prosqlite` (pack) | Driver nativo do SQLite |
| Tailwind CSS (CDN) | Estilização, sem etapa de build |
| Resend | Transporte de email de verificação (produção) |
| Caddy / Podman / cloudflared | HTTPS, container e túnel no deploy |

**Fala:** "Praticamente tudo vem do ecossistema SWI-Prolog: servidor HTTP, geração de HTML, JSON, cripto para senhas e tokens, e `process` para o subprocesso da partida. Externos: só SQLite via prosqlite, Tailwind por CDN e Resend."

---

## 13. Mapa mental do fluxo completo (slide-resumo)

**Código:** [`assets/slides/scotland-yard/README.md`](../assets/slides/scotland-yard/README.md) (roteiro completo)

![[13-mapa-mental]]

**Fala de encerramento:** "Em uma frase: uma aplicação Web completa em torno de um problema de programação lógica - conta e autenticação, envio validado de agentes, partidas executadas de forma assíncrona e isolada, tudo persistido em SQLite e reaproveitado tanto na interface HTML quanto na API JSON."
