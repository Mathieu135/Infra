# Étape 3 — Ingress NGINX + cert-manager + Let's Encrypt

> **Statut : DONE** — Installé via Ansible (rôle `ingress`). Vérifié le 2026-02-17 : tous les pods Running, ClusterIssuer Ready.

## Prérequis

- k3s installé et fonctionnel (étape 2) ✅

## Ce qui est installé

Le rôle Ansible `ingress` installe les 3 composants d'un coup :

### 1. Ingress NGINX ✅

Helm chart `ingress-nginx` (namespace `ingress-nginx`), service type `LoadBalancer`.

### 2. cert-manager ✅

Helm chart `jetstack/cert-manager` (namespace `cert-manager`), CRDs inclus.

### 3. ClusterIssuer `letsencrypt-prod` ✅

HTTP-01 solver via Ingress NGINX. Appliqué directement par Ansible (inline YAML).

```bash
# Installation
make all
# ou spécifiquement le playbook k3s qui inclut le rôle ingress
```

## Utilisation dans les Ingress

Tous les Ingress pourront utiliser le HTTPS automatiquement :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mon-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - app.ton-domaine.com
      secretName: app-tls
  rules:
    - host: app.ton-domaine.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: mon-app
                port:
                  number: 80
```

> Domaine : `matltz.dev` (Cloudflare). Le ClusterIssuer est prêt, les certificats seront générés automatiquement quand un Ingress avec l'annotation sera créé.

## Alternative DNS-01 (pour plus tard)

Pour wildcard `*.matltz.dev`, passer au solver DNS-01 avec l'API Cloudflare.

## Vérification

```bash
# Ingress NGINX
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# cert-manager
kubectl get pods -n cert-manager

# ClusterIssuer
kubectl get clusterissuer
# → letsencrypt-prod   True   ...

# Certificats (après avoir créé un Ingress avec domaine)
kubectl get certificates
```

## Fichiers

- `ansible/roles/ingress/tasks/main.yml` — installation des 3 composants
