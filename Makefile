VPS = vps

tunnel:
	@echo "Tunnel SSH → kubectl sur 127.0.0.1:6443"
	ssh -N -L 6443:127.0.0.1:6443 $(VPS)

ssh:
	ssh $(VPS)

kubeseal:
	@test -n "$(IN)" || (echo "Usage: make kubeseal IN=/tmp/secret.yaml OUT=kubernetes/apps/mon-app/sealed-secret.yaml" && exit 1)
	@test -n "$(OUT)" || (echo "Usage: make kubeseal IN=/tmp/secret.yaml OUT=kubernetes/apps/mon-app/sealed-secret.yaml" && exit 1)
	ssh -f -N -L 6443:127.0.0.1:6443 $(VPS) -o ExitOnForwardFailure=yes
	kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --format yaml < $(IN) > $(OUT)
	@kill $$(lsof -ti:6443) 2>/dev/null || true
	rm -f $(IN)
	@echo "Sealed secret → $(OUT) (secret en clair supprimé)"
