INVENTORY = inventory/hosts.yml
PLAYBOOKS = playbooks/bootstrap.yml playbooks/k3s.yml playbooks/registry.yml playbooks/registry-ui.yml playbooks/argocd.yml playbooks/sealed-secrets.yml playbooks/monitoring.yml playbooks/loki.yml
FLAGS =
RUN = ansible-playbook -i $(INVENTORY)

ping:
	ansible -i $(INVENTORY) all -m ping

bootstrap:
	$(RUN) playbooks/bootstrap.yml $(FLAGS)

check-bootstrap:
	$(RUN) playbooks/bootstrap.yml --check --diff $(FLAGS)

k3s:
	$(RUN) playbooks/k3s.yml $(FLAGS)

check-k3s:
	$(RUN) playbooks/k3s.yml --check --diff $(FLAGS)

registry:
	$(RUN) playbooks/registry.yml $(FLAGS)

check-registry:
	$(RUN) playbooks/registry.yml --check --diff $(FLAGS)

registry-ui:
	$(RUN) playbooks/registry-ui.yml $(FLAGS)

argocd:
	$(RUN) playbooks/argocd.yml $(FLAGS)

sealed-secrets:
	$(RUN) playbooks/sealed-secrets.yml $(FLAGS)

monitoring:
	$(RUN) playbooks/monitoring.yml $(FLAGS)

check-monitoring:
	$(RUN) playbooks/monitoring.yml --check --diff $(FLAGS)

loki:
	$(RUN) playbooks/loki.yml $(FLAGS)

check-loki:
	$(RUN) playbooks/loki.yml --check --diff $(FLAGS)

reset:
	$(RUN) playbooks/reset.yml $(FLAGS)

all:
	@for pb in $(PLAYBOOKS); do $(RUN) $$pb $(FLAGS); done

check:
	@for pb in $(PLAYBOOKS); do $(RUN) $$pb --check --diff $(FLAGS); done
