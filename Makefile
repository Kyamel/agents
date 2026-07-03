# Makefile do agents-battle.
#
#   make dev             # roda o app localmente: swipl src/main.pl
#   make build           # builda a imagem (podman com subuid ok / rootful)
#   make build-rootless  # builda com workaround p/ rootless sem /etc/subuid (ex.: NixOS)
#   make run             # roda a imagem buildada com `build`
#   make run-rootless    # roda a imagem buildada com `build-rootless`
#
# Detalhes de deploy (Caddy, cloudflared, subuid): deploy/README.md

PODMAN ?= podman
IMAGE  ?= agents-app:latest
NAME   ?= agents-app
PORT   ?= 8080

# --- Workaround rootless (host sem /etc/subuid) -------------------------------
# storage.conf com ignore_chown_errors + fuse-overlayfs num graphroot proprio.
ROOTLESS_STORAGE_CONF ?= $(HOME)/.local/share/agents-storage.conf
ROOTLESS_GRAPHROOT    ?= $(HOME)/.local/share/containers-agents
FUSE_OVERLAYFS        ?= /run/current-system/sw/bin/fuse-overlayfs
ROOTLESS_ENV           = CONTAINERS_STORAGE_CONF=$(ROOTLESS_STORAGE_CONF)

RUN_FLAGS = -d --rm --name $(NAME) -p $(PORT):8080 \
	-v agents_data:/app/data -v agents_uploads:/app/uploads

.DEFAULT_GOAL := help

.PHONY: help dev build build-rootless run run-rootless stop logs clean-rootless

help:
	@echo "Alvos:"
	@echo "  make dev             roda o app local (swipl src/main.pl)"
	@echo "  make build           builda a imagem $(IMAGE)"
	@echo "  make build-rootless  builda com workaround rootless (sem /etc/subuid)"
	@echo "  make run             roda a imagem (apos build)"
	@echo "  make run-rootless    roda a imagem (apos build-rootless)"
	@echo "  make stop            para o container $(NAME)"
	@echo "  make logs            segue os logs do container $(NAME)"

# --- Dev local (sem container) ------------------------------------------------
# Sobe o servidor (via initialization(main)) e abre o toplevel do swipl.
# Requer swipl + libsqlite3 no ambiente.
dev:
	swipl src/main.pl

# --- Build da imagem ----------------------------------------------------------
build:
	$(PODMAN) build -f deploy/Containerfile -t $(IMAGE) .

build-rootless: $(ROOTLESS_STORAGE_CONF)
	$(ROOTLESS_ENV) $(PODMAN) build -f deploy/Containerfile -t $(IMAGE) .

# Gera o storage.conf do workaround (so se faltar).
$(ROOTLESS_STORAGE_CONF):
	@mkdir -p $(dir $(ROOTLESS_STORAGE_CONF)) $(ROOTLESS_GRAPHROOT)
	@printf '[storage]\ndriver = "overlay"\ngraphroot = "%s"\n[storage.options.overlay]\nignore_chown_errors = "true"\nmount_program = "%s"\n' \
		'$(ROOTLESS_GRAPHROOT)' '$(FUSE_OVERLAYFS)' > $(ROOTLESS_STORAGE_CONF)
	@echo "gerado $(ROOTLESS_STORAGE_CONF)"

# --- Run da imagem ------------------------------------------------------------
run:
	$(PODMAN) run $(RUN_FLAGS) $(IMAGE)
	@echo "app em http://localhost:$(PORT)  (make logs | make stop)"

run-rootless: $(ROOTLESS_STORAGE_CONF)
	$(ROOTLESS_ENV) $(PODMAN) run $(RUN_FLAGS) $(IMAGE)
	@echo "app em http://localhost:$(PORT)  (make logs | make stop)"

# stop/logs tentam o store default e caem no store do workaround rootless.
stop:
	-$(PODMAN) stop $(NAME) 2>/dev/null || $(ROOTLESS_ENV) $(PODMAN) stop $(NAME) 2>/dev/null || true

logs:
	@$(PODMAN) logs -f $(NAME) 2>/dev/null || $(ROOTLESS_ENV) $(PODMAN) logs -f $(NAME)

# Remove a imagem do store do workaround (mantem volumes/dados). As camadas
# desse store tem uids mapeados, entao use o podman (nao `rm`). Para apagar TUDO
# (inclusive volumes/dados): $(ROOTLESS_ENV) podman system reset
clean-rootless:
	-$(ROOTLESS_ENV) $(PODMAN) rmi -f $(IMAGE)
