# =============================================================================
# Database (PostgreSQL portfolio)
# =============================================================================

K_VPS = ssh $(VPS) "sudo kubectl"

db-shell: ## Shell psql dans le pod PostgreSQL
	ssh -t $(VPS) "sudo kubectl exec -it -n portfolio portfolio-postgres-0 -- psql -U portfolio"

db-backup: ## Déclenche un backup pg_dump immédiat
	$(K_VPS) create job --from=cronjob/portfolio-pg-backup manual-backup-$$(date +%s) -n portfolio"
	@echo "$(GREEN)[OK]$(RESET) Job de backup lancé"

db-logs: ## Logs du pod PostgreSQL
	$(K_VPS) logs -n portfolio portfolio-postgres-0 --tail=50"
