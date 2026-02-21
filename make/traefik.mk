# =============================================================================
# Traefik local (reverse proxy *.localhost)
# =============================================================================

TRAEFIK_DIR = $(CURDIR)/traefik

traefik-install: ## Installe mkcert et génère les certificats *.localhost
	@command -v mkcert >/dev/null 2>&1 || (echo "Installation de mkcert..." && brew install mkcert)
	@mkcert -install 2>/dev/null
	@if [ ! -f "$(TRAEFIK_DIR)/certs/local.pem" ]; then \
		mkdir -p $(TRAEFIK_DIR)/certs; \
		mkcert -cert-file $(TRAEFIK_DIR)/certs/local.pem \
		       -key-file $(TRAEFIK_DIR)/certs/local-key.pem \
		       localhost traefik.localhost grafana.localhost argocd.localhost \
		       prometheus.localhost portfolio.localhost; \
		echo "\033[0;32m[OK]\033[0m Certificats générés"; \
	else echo "\033[0;32m[SKIP]\033[0m Certificats déjà présents"; fi

traefik: ## Lance Traefik local (https://*.localhost)
	@if [ ! -f "$(TRAEFIK_DIR)/certs/local.pem" ]; then \
		echo "\033[1;33m[WARN]\033[0m Certificats manquants, lancement de traefik-install..."; \
		$(MAKE) traefik-install; \
	fi
	@docker compose -f $(TRAEFIK_DIR)/docker-compose.yml up -d
	@echo "\033[0;32m[OK]\033[0m Traefik → https://traefik.localhost"

ensure-traefik:
	@docker ps --filter "publish=80" --format '{{.Names}}' | grep -q . || $(MAKE) traefik

traefik-down: ## Stoppe Traefik local
	@docker compose -f $(TRAEFIK_DIR)/docker-compose.yml down
	@echo "\033[0;31m[STOP]\033[0m Traefik"
