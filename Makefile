VPS = vps

include k8s.mk

.PHONY: help tunnel ssh ensure-tunnel traefik traefik-down traefik-install ensure-traefik vps pf-argocd pf-grafana pf-all pf-ls pf-stop pf-down _pf-gen _pf-stop secrets-edit secrets-view secrets-create

# --- Couleurs ---
CYAN   = \033[0;36m
GREEN  = \033[0;32m
RED    = \033[0;31m
YELLOW = \033[1;33m
BOLD   = \033[1m
DIM    = \033[2m
RESET  = \033[0m

help: ## Affiche cette aide
	@echo ""
	@echo "$(BOLD)  Infra — VPS k3s ($(VPS))$(RESET)"
	@echo ""
	@echo "$(YELLOW)Connexion$(RESET)"
	@grep -E '^(ssh|tunnel):.*##' Makefile | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Traefik local$(RESET)"
	@grep -E '^traefik[a-z-]*:.*##' Makefile | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Port-forwards$(RESET)"
	@grep -E '^pf-[a-z-]+:.*##' Makefile | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Secrets$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*##' Makefile | grep -E 'secrets' | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Kubernetes$(RESET)  $(DIM)(k8s.mk)$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*##' k8s.mk | sort | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Ansible$(RESET)  $(DIM)(ansible/)$(RESET)"
	@$(MAKE) -C ansible --no-print-directory _help-targets 2>/dev/null || grep -E '^[a-zA-Z_-]+:.*##' ansible/Makefile | sort | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""

# Déléguer les targets inconnus au Makefile ansible
%:
	$(MAKE) -C ansible $@

# =============================================================================
# Connexion
# =============================================================================

tunnel: ## Tunnel SSH kubectl (port 26443)
	@echo "Tunnel SSH → kubectl sur 127.0.0.1:26443"
	ssh -N -L 26443:127.0.0.1:6443 $(VPS)

ssh: ## SSH vers le VPS
	ssh $(VPS)

ensure-tunnel:
	@lsof -ti:26443 >/dev/null 2>&1 || (echo "Ouverture du tunnel SSH..." && ssh -f -N -L 26443:127.0.0.1:6443 $(VPS) -o ExitOnForwardFailure=yes)

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
	@docker inspect infra_traefik --format '{{.State.Running}}' 2>/dev/null | grep -q true || $(MAKE) traefik

traefik-down: ## Stoppe Traefik local
	@docker compose -f $(TRAEFIK_DIR)/docker-compose.yml down
	@echo "\033[0;31m[STOP]\033[0m Traefik"

# =============================================================================
# Port-forwards (kubectl → Traefik)
# =============================================================================

PF_DYNAMIC = $(TRAEFIK_DIR)/dynamic/portforwards.yml
PF_PID_DIR = $(CURDIR)/.pf-pids

pf-argocd: ensure-tunnel ensure-traefik ## Port-forward ArgoCD → https://argocd.localhost
	@mkdir -p $(PF_PID_DIR)
	@$(MAKE) _pf-stop NAME=argocd 2>/dev/null || true
	kubectl port-forward svc/argocd-server -n argocd --address 127.0.0.1 8081:80 &>/dev/null & echo $$! > $(PF_PID_DIR)/argocd
	@echo "8081" >> $(PF_PID_DIR)/argocd
	@sleep 1
	@$(MAKE) _pf-gen
	@echo "\033[0;32m[OK]\033[0m argocd → https://argocd.localhost"

pf-grafana: ensure-tunnel ensure-traefik ## Port-forward Grafana → https://grafana.localhost
	@mkdir -p $(PF_PID_DIR)
	@$(MAKE) _pf-stop NAME=grafana 2>/dev/null || true
	kubectl port-forward svc/monitoring-grafana -n monitoring --address 127.0.0.1 3000:80 &>/dev/null & echo $$! > $(PF_PID_DIR)/grafana
	@echo "3000" >> $(PF_PID_DIR)/grafana
	@sleep 1
	@$(MAKE) _pf-gen
	@echo "\033[0;32m[OK]\033[0m grafana → https://grafana.localhost"

vps: ## Affiche les PV et le stockage du VPS
	@ssh $(VPS) 'sudo kubectl get pv && echo "" && echo "--- /opt/k3s-data/ ---" && sudo ls -la /opt/k3s-data/ 2>/dev/null || echo "(vide)"'

pf-all: pf-argocd pf-grafana ## Lance tous les port-forwards

pf-ls: ## Liste les port-forwards actifs
	@if [ -d "$(PF_PID_DIR)" ] && [ "$$(ls -A $(PF_PID_DIR) 2>/dev/null)" ]; then \
		printf "\033[1m%-15s %-30s %-8s %-8s\033[0m\n" "NOM" "URL" "PORT" "STATUS"; \
		for f in $(PF_PID_DIR)/*; do \
			name=$$(basename $$f); \
			pid=$$(head -1 $$f); \
			port=$$(tail -1 $$f); \
			if kill -0 $$pid 2>/dev/null; then status="\033[0;32mrunning\033[0m"; else status="\033[0;31mdead\033[0m"; fi; \
			printf "%-15s %-30s %-8s $$(echo -e $$status)\n" "$$name" "https://$$name.localhost" "$$port"; \
		done; \
	else echo "Aucun port-forward actif"; fi

pf-stop: ## Stoppe un forward : make pf-stop NAME=grafana
	@if [ -f "$(PF_PID_DIR)/$(NAME)" ]; then \
		kill $$(head -1 $(PF_PID_DIR)/$(NAME)) 2>/dev/null || true; \
		rm $(PF_PID_DIR)/$(NAME); \
		$(MAKE) _pf-gen; \
		echo "\033[0;31m[STOP]\033[0m $(NAME)"; \
	else echo "$(NAME) n'est pas actif"; fi

pf-down: ## Stoppe tous les forwards
	@if [ -d "$(PF_PID_DIR)" ] && [ "$$(ls -A $(PF_PID_DIR) 2>/dev/null)" ]; then \
		for f in $(PF_PID_DIR)/*; do \
			kill $$(head -1 $$f) 2>/dev/null || true; \
			echo "\033[0;31m[STOP]\033[0m $$(basename $$f)"; \
		done; \
		rm -rf $(PF_PID_DIR); \
		$(MAKE) _pf-gen; \
	else echo "Aucun forward actif"; fi

# Interne : régénère la config Traefik depuis les PID files
_pf-gen:
	@if [ -d "$(PF_PID_DIR)" ] && [ "$$(ls -A $(PF_PID_DIR) 2>/dev/null)" ]; then \
		{ echo "http:"; echo "  routers:"; \
		for f in $(PF_PID_DIR)/*; do \
			n=$$(basename $$f); \
			echo "    $$n:"; \
			echo "      rule: \"Host(\`$$n.localhost\`)\""; \
			echo "      service: $$n"; \
			echo "      tls: {}"; \
		done; \
		echo ""; echo "  services:"; \
		for f in $(PF_PID_DIR)/*; do \
			n=$$(basename $$f); p=$$(tail -1 $$f); \
			echo "    $$n:"; \
			echo "      loadBalancer:"; \
			echo "        servers:"; \
			echo "          - url: \"http://host.docker.internal:$$p\""; \
		done; } > $(PF_DYNAMIC); \
	else \
		echo "http:" > $(PF_DYNAMIC); \
		echo "  routers: {}" >> $(PF_DYNAMIC); \
		echo "  services: {}" >> $(PF_DYNAMIC); \
	fi

_pf-stop:
	@if [ -f "$(PF_PID_DIR)/$(NAME)" ]; then \
		kill $$(head -1 $(PF_PID_DIR)/$(NAME)) 2>/dev/null || true; \
		rm $(PF_PID_DIR)/$(NAME); \
	fi

# =============================================================================
# Secrets (SOPS + age)
# =============================================================================

secrets-edit: ## Édite un secret chiffré : make secrets-edit APP=portfolio
	@test -n "$(APP)" || (echo "Usage: make secrets-edit APP=<nom>" && exit 1)
	sops kubernetes/apps/$(APP)/secrets.enc.yaml

secrets-view: ## Affiche un secret en clair : make secrets-view APP=portfolio
	@test -n "$(APP)" || (echo "Usage: make secrets-view APP=<nom>" && exit 1)
	sops -d kubernetes/apps/$(APP)/secrets.enc.yaml

secrets-create: ## Crée un nouveau secret chiffré : make secrets-create APP=portfolio
	@test -n "$(APP)" || (echo "Usage: make secrets-create APP=<nom>" && exit 1)
	@mkdir -p kubernetes/apps/$(APP)
	@echo 'apiVersion: v1' > kubernetes/apps/$(APP)/secrets.enc.yaml
	@echo 'kind: Secret' >> kubernetes/apps/$(APP)/secrets.enc.yaml
	@echo 'metadata:' >> kubernetes/apps/$(APP)/secrets.enc.yaml
	@echo '  name: $(APP)-secrets' >> kubernetes/apps/$(APP)/secrets.enc.yaml
	@echo '  namespace: $(APP)' >> kubernetes/apps/$(APP)/secrets.enc.yaml
	@echo 'stringData:' >> kubernetes/apps/$(APP)/secrets.enc.yaml
	@echo '  KEY: value' >> kubernetes/apps/$(APP)/secrets.enc.yaml
	sops -e -i kubernetes/apps/$(APP)/secrets.enc.yaml
	@test -f kubernetes/apps/$(APP)/ksops-generator.yaml || ( \
		echo 'apiVersion: viaduct.ai/v1' > kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo 'kind: ksops' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo 'metadata:' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo '  name: $(APP)-secrets' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo '  annotations:' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo '    config.kubernetes.io/function: |' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo '      exec:' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo '        path: ksops' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo 'files:' >> kubernetes/apps/$(APP)/ksops-generator.yaml && \
		echo '  - secrets.enc.yaml' >> kubernetes/apps/$(APP)/ksops-generator.yaml \
	)
	@echo "Secret créé → kubernetes/apps/$(APP)/secrets.enc.yaml"
	@echo "Generator  → kubernetes/apps/$(APP)/ksops-generator.yaml"
