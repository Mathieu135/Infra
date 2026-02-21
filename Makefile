VPS = vps

# --- Sous-makefiles ---
include make/connexion.mk
include make/traefik.mk
include make/portforward.mk
include make/database.mk
include make/secrets.mk
include make/k8s.mk

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
	@grep -hE '^(ssh|tunnel|vps):.*##' make/connexion.mk | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Traefik local$(RESET)"
	@grep -hE '^traefik[a-z-]*:.*##' make/traefik.mk | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Port-forwards$(RESET)"
	@grep -hE '^pf-[a-z-]+:.*##' make/portforward.mk | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Database$(RESET)"
	@grep -hE '^db-[a-z-]+:.*##' make/database.mk | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Secrets$(RESET)"
	@grep -hE '^secrets-[a-z-]+:.*##' make/secrets.mk | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Kubernetes$(RESET)  $(DIM)(make/k8s.mk)$(RESET)"
	@grep -hE '^[a-zA-Z_-]+:.*##' make/k8s.mk | sort | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""
	@echo "$(YELLOW)Ansible$(RESET)  $(DIM)(ansible/)$(RESET)"
	@$(MAKE) -C ansible --no-print-directory _help-targets 2>/dev/null || grep -E '^[a-zA-Z_-]+:.*##' ansible/Makefile | sort | awk -F ':.*## ' '{ printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 }'
	@echo ""

# Déléguer les targets inconnus au Makefile ansible
%:
	$(MAKE) -C ansible $@
