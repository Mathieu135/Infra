# Étape 5 — ArgoCD

## Prérequis

- k3s fonctionnel (étape 2)
- cert-manager configuré (étape 3)
- DNS configuré : `argocd.ton-domaine.com` → IP du serveur

## Installation

```bash
# Créer le namespace
kubectl create namespace argocd

# Installer ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Ou via Helm (plus configurable) :

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.ingress.enabled=true \
  --set server.ingress.hosts[0]=argocd.ton-domaine.com
```

## Ingress

```yaml
# kubernetes/argocd/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # ArgoCD utilise gRPC, important pour NGINX
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  tls:
    - hosts:
        - argocd.ton-domaine.com
      secretName: argocd-tls
  rules:
    - host: argocd.ton-domaine.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

## Premier accès

```bash
# Récupérer le mot de passe admin initial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Se connecter
# User : admin
# Password : le mot de passe récupéré ci-dessus
```

Changer le mot de passe admin immédiatement après la première connexion.

## Installer la CLI ArgoCD

```bash
brew install argocd

# Se connecter
argocd login argocd.ton-domaine.com

# Changer le mot de passe
argocd account update-password
```

## Connecter le repo GitHub

### Option A — Deploy key (recommandé)

```bash
# Générer une clé dédiée
ssh-keygen -t ed25519 -f ~/.ssh/argocd-deploy -N ""

# Ajouter la clé publique dans GitHub → repo infra → Settings → Deploy keys (read-only)

# Ajouter le repo dans ArgoCD
argocd repo add git@github.com:ton-user/infra.git \
  --ssh-private-key-path ~/.ssh/argocd-deploy
```

### Option B — Via l'UI

Settings → Repositories → Connect Repo → SSH → coller la clé privée.

## Créer une Application ArgoCD

Chaque projet déployé est une "Application" ArgoCD :

```yaml
# kubernetes/argocd/apps/exemple.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mon-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:ton-user/infra.git
    targetRevision: main
    path: kubernetes/apps/mon-app
  destination:
    server: https://kubernetes.default.svc
    namespace: mon-app
  syncPolicy:
    automated:
      prune: true        # supprime les ressources retirées du Git
      selfHeal: true     # remet en état si modifié manuellement
    syncOptions:
      - CreateNamespace=true
```

## App of Apps pattern (optionnel, recommandé)

Un seul Application qui pointe vers un dossier contenant d'autres Applications :

```yaml
# kubernetes/argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:ton-user/infra.git
    targetRevision: main
    path: kubernetes/argocd/apps  # contient les yamls de chaque Application
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      selfHeal: true
```

Ajouter un nouveau projet = ajouter un YAML dans `kubernetes/argocd/apps/`.

## Vérification

```bash
# Vérifier qu'ArgoCD tourne
kubectl get pods -n argocd

# Lister les apps
argocd app list

# Voir le statut d'une app
argocd app get mon-app
```

## Fichiers à créer

- `kubernetes/argocd/ingress.yaml`
- `kubernetes/argocd/app-of-apps.yaml`
- `kubernetes/argocd/apps/` — un YAML par projet
