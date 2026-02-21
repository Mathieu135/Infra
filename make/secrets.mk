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
