# Étape 4 — Docker Registry self-hosted

> **Statut : DONE** — Installé via Ansible. Vérifié le 2026-02-17.

## Prérequis

- k3s fonctionnel (étape 2) ✅
- cert-manager configuré (étape 3) ✅
- DNS : `registry.matltz.dev → 91.134.142.175` (Cloudflare, DNS only) ✅

## Architecture

```
Internet → registry.matltz.dev (ingress + basic-auth + rate limit)
  → UI pod (:80)
    → /        : interface web
    → /v2/*    : proxy vers registry pod (:5000, interne)
```

- Un seul point d'entrée : `registry.matltz.dev`
- L'UI (Joxit, mode proxy) sert la web UI ET proxy les requêtes Docker vers le registry
- Le registry pod n'est pas exposé sur Internet (service interne uniquement)
- Auth basic-auth sur l'ingress (credentials dans Ansible Vault)
- Rate limiting : 10 req/s, 5 connexions simultanées

## Ce qui est installé

### Rôle `registry` (`make registry`)

1. **Docker Registry** via Helm (`twuni/docker-registry`), persistence 20Gi ✅
2. **Ingress** sur `registry.matltz.dev` avec TLS + basic-auth + rate limiting ✅
3. **Config k3s** (`/etc/rancher/k3s/registries.yaml`) pour pull depuis le registry ✅

### Rôle `registry-ui` (`make registry-ui`)

4. **Docker Registry UI** via Helm (`joxit/docker-registry-ui`, mode proxy) ✅

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
https://registry.matltz.dev
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
- `ansible/roles/registry-ui/tasks/main.yml` — UI Helm
- Credentials dans `ansible/inventory/group_vars/all/vault.yml`
