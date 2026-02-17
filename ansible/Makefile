INVENTORY = inventory/hosts.yml
PLAYBOOKS = playbooks/bootstrap.yml playbooks/k3s.yml
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

reset:
	$(RUN) playbooks/reset.yml $(FLAGS)

all:
	@for pb in $(PLAYBOOKS); do $(RUN) $$pb $(FLAGS); done

check:
	@for pb in $(PLAYBOOKS); do $(RUN) $$pb --check --diff $(FLAGS); done
