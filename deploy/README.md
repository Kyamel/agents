# Deploy (Podman + Caddy)

Imagem do app em **Debian slim** (SWI-Prolog + SQLite via `prosqlite`) com
**Caddy** na frente terminando **HTTPS**. Pensado para rodar no notebook e ser
exposto por um **cloudflared tunnel**.

```
deploy/
  Containerfile   # imagem do app (SWI-Prolog + libsqlite3 + prosqlite)
  Caddyfile       # Caddy: HTTPS -> reverse_proxy para o app:8080
  compose.yaml    # app + caddy (podman-compose / podman compose)
```

## Ambiente: rootless sem /etc/subuid (NixOS)

Em host que roda **podman rootless sem `/etc/subuid`/`/etc/subgid`**, o build
falha no unpack da imagem base e no `apt` (mapeamento de uid único). Duas saídas:

**A) Recomendado — configurar subuid/subgid no NixOS** (`configuration.nix`):

```nix
virtualisation.containers.enable = true;
virtualisation.podman.enable = true;
users.users.youruser.subUidRanges = [{ startUid = 100000; count = 65536; }];
users.users.youruser.subGidRanges = [{ startGid = 100000; count = 65536; }];
```

`sudo nixos-rebuild switch` e depois `podman system migrate`. Aí tudo funciona
normalmente.

**B) Workaround sem mexer no sistema — `ignore_chown_errors`** (desempacota
ignorando o chown que exige subuid). Crie um `storage.conf` e aponte o podman
para ele:

```sh
cat > /tmp/agents-storage.conf <<'EOF'
[storage]
driver = "overlay"
graphroot = "/home/lucas/.local/share/containers-agents"
[storage.options.overlay]
ignore_chown_errors = "true"
mount_program = "/run/current-system/sw/bin/fuse-overlayfs"
EOF
export CONTAINERS_STORAGE_CONF=/tmp/agents-storage.conf
```

Com essa variável exportada, os comandos abaixo (`podman build`, `podman-compose`)
funcionam. O fix do `apt` (rodar como root) já está embutido no Containerfile.

## Subir tudo

A partir da pasta `deploy/`:

```sh
# localhost (HTTPS self-signed via CA interna do Caddy)
podman-compose up -d --build

# com dominio proprio
SITE_ADDRESS=agents.seudominio.com podman-compose up -d --build
```

> `podman compose up -d --build` também funciona (usa o provider docker-compose).

- App: só na rede interna, porta `8080` (HTTP).
- Caddy: publica `80`/`443` no host e faz o proxy pro app.
- HTTPS: `https://localhost` (certificado self-signed da CA interna do Caddy).

Dados persistem em volumes (`app_data` = SQLite em `/app/data`, `app_uploads` =
código dos agentes). `caddy_data` guarda os certificados.

## Build/rodar só a imagem do app (sem compose)

```sh
# a partir da RAIZ do projeto (o contexto precisa ser a raiz)
podman build -f deploy/Containerfile -t agents-app .

podman run --rm -p 8080:8080 \
  -v agents_data:/app/data -v agents_uploads:/app/uploads \
  agents-app
# app em http://localhost:8080
```

## cloudflared tunnel

O Caddy serve HTTPS com a CA interna, então aponte o tunnel para o Caddy
ignorando a verificação de certificado (o Cloudflare entrega o HTTPS válido na
ponta):

```yaml
# ~/.cloudflared/config.yml (exemplo)
ingress:
  - hostname: agents.seudominio.com
    service: https://localhost:443
    originRequest:
      noTLSVerify: true
  - service: http_status:404
```

E use `SITE_ADDRESS=agents.seudominio.com` no compose para o Caddy responder por
esse host.

> Alternativa: se preferir HTTP puro entre cloudflared e o app (deixando o TLS
> 100% no Cloudflare), aponte o tunnel direto para `http://localhost:8080` e
> dispense o Caddy.

## Certificados reais (Let's Encrypt) em vez de self-signed

Como atrás do tunnel o Caddy não é alcançável publicamente para o desafio HTTP,
use o **DNS challenge da Cloudflare**. Isso exige um build do Caddy com o plugin
`caddy-dns/cloudflare` e um API token. No `Caddyfile`, troque `tls internal` por:

```
tls {
	dns cloudflare {$CF_API_TOKEN}
}
```

## Ajustes de configuração recomendados (atrás de proxy)

Para produção atrás do Caddy/tunnel, considere editar [`src/config.pl`](../src/config.pl):

- `trust_proxy(true)` — para o rate-limit por IP honrar `X-Forwarded-For` que o
  Caddy injeta (senão todos os pedidos vêm do IP do proxy). Atenção: com
  cloudflared no meio, o IP "real" do cliente vem no header `CF-Connecting-IP`;
  o `X-Forwarded-For` do Caddy reflete a conexão do cloudflared.
- `app_base_url("https://agents.seudominio.com")` — usado nos links dos emails
  de verificação. Só relevante com `mail_transport` real (o padrão é `console`,
  que só imprime o link no log do container).

## Notas técnicas

- **prosqlite**: a lib nativa (`packs/prosqlite/lib/x86_64-linux/prosqlite.so`)
  é carregada via `pack_attach` e só depende de `libsqlite3.so.0`
  (`libsqlite3-0`). O build tem um passo que falha cedo se ela não carregar com
  o SWI-Prolog da imagem — se isso acontecer (ex.: outra arquitetura), recompile
  o pack com `swipl-ld`/`make` dentro de um builder e copie o `.so`.
- **swi-prolog-nox** já inclui `library(crypto)` (hash de senha), `http` e `ssl`.
- O app roda o servidor via `initialization(main)` e bloqueia com
  `main_foreground` para o container permanecer no ar.
