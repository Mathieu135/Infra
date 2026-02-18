INVENTORY = inventory/hosts.yml
PLAYBOOKS = playbooks/bootstrap.yml playbooks/k3s.yml playbooks/ingress.yml playbooks/registry.yml playbooks/registry-ui.yml playbooks/argocd.yml playbooks/monitoring.yml playbooks/loki.yml
FLAGS =
RUN = ansible-playbook -i $(INVENTORY)

help: ## Affiche cette aide
	@printf "\033[1m%-20s %s\033[0m\n" "TARGET" "DESCRIPTION"
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk -F ':.*## ' '{ printf "  %-18s %s\n", $$1, $$2 }'

ping: ## Ping les hosts
	ansible -i $(INVENTORY) all -m ping

bootstrap: ## Provisionner le VPS
	$(RUN) playbooks/bootstrap.yml $(FLAGS)

check-bootstrap: ## Dry-run bootstrap
	$(RUN) playbooks/bootstrap.yml --check --diff $(FLAGS)

k3s: ## Installer/upgrader k3s
	$(RUN) playbooks/k3s.yml $(FLAGS)

check-k3s: ## Dry-run k3s
	$(RUN) playbooks/k3s.yml --check --diff $(FLAGS)

registry: ## Installer/upgrader la registry Docker
	$(RUN) playbooks/registry.yml $(FLAGS)

check-registry: ## Dry-run registry
	$(RUN) playbooks/registry.yml --check --diff $(FLAGS)

registry-ui: ## Installer/upgrader la registry UI
	$(RUN) playbooks/registry-ui.yml $(FLAGS)

argocd: ## Installer/upgrader ArgoCD
	$(RUN) playbooks/argocd.yml $(FLAGS)

monitoring: ## Installer/upgrader Prometheus + Grafana
	$(RUN) playbooks/monitoring.yml $(FLAGS)

check-monitoring: ## Dry-run monitoring
	$(RUN) playbooks/monitoring.yml --check --diff $(FLAGS)

ingress: ## Installer/upgrader Ingress NGINX + cert-manager
	$(RUN) playbooks/ingress.yml $(FLAGS)

check-ingress: ## Dry-run ingress
	$(RUN) playbooks/ingress.yml --check --diff $(FLAGS)

loki: ## Installer/upgrader Loki + Promtail
	$(RUN) playbooks/loki.yml $(FLAGS)

check-loki: ## Dry-run loki
	$(RUN) playbooks/loki.yml --check --diff $(FLAGS)

vault-view: ## Voir le vault Ansible
	ansible-vault view inventory/group_vars/all/vault.yml

vault-edit: ## Editer le vault Ansible
	ansible-vault edit inventory/group_vars/all/vault.yml

reset: ## Reset complet du VPS
	$(RUN) playbooks/reset.yml $(FLAGS)

all: ## Lancer tous les playbooks
	@for pb in $(PLAYBOOKS); do $(RUN) $$pb $(FLAGS); done

check: ## Dry-run tous les playbooks
	@for pb in $(PLAYBOOKS); do $(RUN) $$pb --check --diff $(FLAGS); done
