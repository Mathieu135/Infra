# --- Commandes kubectl (via SSH) ---

K = ssh $(VPS) "sudo kubectl"

pods: ## Tous les pods groupés par namespace
	@$(K) get pods -A -o json | python3 scripts/format-pods.py

pods-app: ## Pods applicatifs (hors système)
	@$(K) get pods -A -o json | python3 scripts/format-pods.py --app-only

status: ## Vue d'ensemble du cluster
	@echo "\033[1m--- Nodes ---\033[0m"
	@$(K) get nodes -o wide
	@echo ""
	@echo "\033[1m--- Pods non-Running ---\033[0m"
	@$(K) get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null || echo "  Tout est OK"
	@echo ""
	@echo "\033[1m--- Top pods (CPU/Mem) ---\033[0m"
	@$(K) top pods -A --sort-by=memory 2>/dev/null || echo "  metrics-server non disponible"

logs: ## Logs d'un pod : make logs NS=portfolio APP=backend
	@test -n "$(NS)" || (echo "Usage: make logs NS=<namespace> APP=<nom>" && exit 1)
	@$(K) logs -n $(NS) -l app=portfolio-$(APP) --tail=50

restarts: ## Pods avec restarts récents
	@$(K) get pods -A -o json | python3 scripts/format-pods.py | grep "↻" || echo "Aucun restart"

svc: ## Services avec labels
	@$(K) get svc -A --show-labels

events: ## Événements récents (warnings)
	@$(K) get events -A --field-selector=type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -20 || echo "  Aucun warning"
