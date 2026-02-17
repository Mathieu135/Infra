VPS = vps

tunnel:
	@echo "Tunnel SSH → kubectl sur 127.0.0.1:26443"
	ssh -N -L 26443:127.0.0.1:6443 $(VPS)

ssh:
	ssh $(VPS)

kubeseal:
	@test -n "$(IN)" || (echo "Usage: make kubeseal IN=/tmp/secret.yaml OUT=kubernetes/apps/mon-app/sealed-secret.yaml" && exit 1)
	@test -n "$(OUT)" || (echo "Usage: make kubeseal IN=/tmp/secret.yaml OUT=kubernetes/apps/mon-app/sealed-secret.yaml" && exit 1)
	ssh -f -N -L 26443:127.0.0.1:6443 $(VPS) -o ExitOnForwardFailure=yes
	kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > /tmp/kubeseal-cert.pem
	kubeseal --format yaml --cert /tmp/kubeseal-cert.pem < $(IN) > $(OUT)
	rm -f /tmp/kubeseal-cert.pem
	@kill $$(lsof -ti:26443) 2>/dev/null || true
	rm -f $(IN)
	@echo "Sealed secret → $(OUT) (secret en clair supprimé)"
