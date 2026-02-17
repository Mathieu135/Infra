# Étape 3 — cert-manager + Let's Encrypt

## Prérequis

- k3s installé et fonctionnel (étape 2)
- Un nom de domaine avec DNS pointant vers l'IP du serveur
- `kubectl` et `helm` configurés sur ton Mac

## Pourquoi cert-manager

- Génère et renouvelle automatiquement les certificats TLS
- S'intègre avec Traefik via les annotations Ingress
- Supporte Let's Encrypt (gratuit)

## Installation

```bash
# Ajouter le repo Helm
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Installer cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

## Configurer le ClusterIssuer

Deux options :

### Option A — HTTP-01 (simple, recommandé pour commencer)

Nécessite que les ports 80/443 soient ouverts et le domaine pointe vers le serveur.

```yaml
# kubernetes/cert-manager/cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ton-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: traefik
```

### Option B — DNS-01 (pour wildcard *.ton-domaine.com)

Nécessite un provider DNS supporté (Cloudflare, OVH, etc.).

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ton-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - dns01:
          cloudflare:
            email: ton-email@example.com
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

## Appliquer

```bash
kubectl apply -f kubernetes/cert-manager/cluster-issuer.yaml
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

## Vérification

```bash
# Vérifier que cert-manager tourne
kubectl get pods -n cert-manager

# Vérifier le ClusterIssuer
kubectl get clusterissuer
# → letsencrypt-prod   True   ...

# Vérifier un certificat (après avoir créé un Ingress)
kubectl get certificates
```

## Fichiers à créer

- `kubernetes/cert-manager/cluster-issuer.yaml`
