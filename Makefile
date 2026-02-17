VPS = vps

tunnel:
	@echo "Tunnel SSH → kubectl sur 127.0.0.1:6443"
	ssh -N -L 6443:127.0.0.1:6443 $(VPS)

ssh:
	ssh $(VPS)
