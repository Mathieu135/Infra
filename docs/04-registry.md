# Étape 4 — Docker Registry self-hosted

> **Statut : DONE** — Installé via Ansible. Vérifié le 2026-02-17 : push/pull + UI fonctionnels.

## Prérequis

- k3s fonctionnel (étape 2) ✅
- cert-manager configuré (étape 3) ✅
- DNS Cloudflare (DNS only, proxy désactivé) :
  - `registry.matltz.dev → 91.134.142.175` ✅
  - `registry-ui.matltz.dev → 91.134.142.175` ✅

## Architecture

```
Internet → registry.matltz.dev (ingress + basic-auth) → registry pod (:5000)
Internet → registry-ui.matltz.dev (ingress)           → UI pod (:80) → registry pod (interne, sans auth)
```

- L'auth (htpasswd) est gérée au niveau de l'ingress, pas dans le registry
- L'UI accède au registry via le service Kubernetes interne (pas d'auth nécessaire)
- Credentials stockés dans Ansible Vault

## Ce qui est installé

### Rôle `registry` (`make registry`)

1. **Docker Registry** via Helm (`twuni/docker-registry`), persistence 20Gi ✅
2. **Ingress** sur `registry.matltz.dev` avec TLS + basic-auth ✅
3. **Config k3s** (`/etc/rancher/k3s/registries.yaml`) pour pull depuis le registry ✅

### Rôle `registry-ui` (`make registry-ui`)

4. **Docker Registry UI** via Helm (`joxit/docker-registry-ui`) ✅
5. **Ingress** sur `registry-ui.matltz.dev` avec TLS ✅

## Utilisation

```bash
# Login
docker login registry.matltz.dev

# Push une image
docker tag mon-app:latest registry.matltz.dev/mon-app:latest
docker push registry.matltz.dev/mon-app:latest

# Lister les images
curl -u <user> https://registry.matltz.dev/v2/_catalog

# Interface web
https://registry-ui.matltz.dev
```

## Vérification

```bash
kubectl get pods -n registry
kubectl get ingress -n registry
kubectl get certificates -n registry
```

## Fichiers

- `ansible/playbooks/registry.yml`
- `ansible/roles/registry/tasks/main.yml` — registry + ingress + auth + config k3s
- `ansible/roles/registry/handlers/main.yml` — restart k3s
- `ansible/playbooks/registry-ui.yml`
- `ansible/roles/registry-ui/tasks/main.yml` — UI + ingress
- Credentials dans `ansible/inventory/group_vars/all/vault.yml`
