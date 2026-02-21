# =============================================================================
# Connexion SSH / Tunnel kubectl
# =============================================================================

tunnel: ## Tunnel SSH kubectl (port 26443)
	@echo "Tunnel SSH → kubectl sur 127.0.0.1:26443"
	ssh -N -L 26443:127.0.0.1:6443 $(VPS)

ssh: ## SSH vers le VPS
	ssh $(VPS)

vps: ## Affiche les PV et le stockage du VPS
	@ssh $(VPS) 'sudo kubectl get pv && echo "" && echo "--- /opt/k3s-data/ ---" && sudo ls -la /opt/k3s-data/ 2>/dev/null || echo "(vide)"'

ensure-tunnel:
	@lsof -ti:26443 >/dev/null 2>&1 || (echo "Ouverture du tunnel SSH..." && ssh -f -N -L 26443:127.0.0.1:6443 $(VPS) -o ExitOnForwardFailure=yes)
