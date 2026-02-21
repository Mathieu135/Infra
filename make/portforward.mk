# =============================================================================
# Port-forwards (kubectl → Traefik)
# =============================================================================

PF_DYNAMIC = /Volumes/External/projects/dev-tools/traefik/dynamic/portforwards.yml
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
