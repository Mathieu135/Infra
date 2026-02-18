# Étape 5 — ArgoCD

> **Statut : DONE** — Installé via Ansible (rôle `argocd`). Vérifié le 2026-02-17.

## Prérequis

- k3s fonctionnel (étape 2) ✅
- cert-manager configuré (étape 3) ✅
- DNS : `argocd.matltz.dev → 91.134.142.175` (Cloudflare, DNS only) ✅

## Architecture

```
Client → HTTPS → Ingress NGINX (TLS terminé ici) → HTTP → ArgoCD pod
```

Mode `insecure` (recommandé par ArgoCD) : le TLS est géré par l'ingress, le trafic interne au cluster est en HTTP.

## Installation via Ansible ✅

```bash
make argocd
```

Le playbook :
1. Installe/upgrade ArgoCD via Helm
2. Applique automatiquement toutes les Applications depuis `kubernetes/argocd/apps/`
3. Affiche le mot de passe admin initial

## Premier accès

- URL : `https://argocd.matltz.dev`
- User : `admin`
- Password : affiché par `make argocd` ou :

```bash
ssh vps "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

Changer le mot de passe immédiatement :

```bash
brew install argocd
argocd login argocd.matltz.dev
argocd account update-password
```

Nouveau mot de passe stocké dans Ansible Vault.

## Connecter le repo GitHub

### Option A — Deploy key (recommandé)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/argocd-deploy -N ""

# Ajouter la clé publique dans GitHub → repo infra → Settings → Deploy keys (read-only)

argocd repo add git@github.com:ton-user/infra.git \
  --ssh-private-key-path ~/.ssh/argocd-deploy
```

### Option B — Via l'UI

Settings → Repositories → Connect Repo → SSH → coller la clé privée.

## Créer une Application ArgoCD

```yaml
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
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## App of Apps pattern (recommandé)

Un seul Application qui pointe vers un dossier contenant d'autres Applications :

```yaml
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
    path: kubernetes/argocd/apps
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
kubectl get pods -n argocd
argocd app list
```

## Applications gérées

| App | Source | Namespace cible |
|-----|--------|-----------------|
| `portfolio` | `kubernetes/apps/portfolio` | portfolio |
| `monitoring-dashboards` | `kubernetes/monitoring` | monitoring |
| `registry-maintenance` | `kubernetes/registry` | registry |
| `argocd-policies` | `kubernetes/argocd-policies` | argocd |

Ajouter une app = créer un YAML dans `kubernetes/argocd/apps/` puis `make argocd`.

## Fichiers

- `ansible/playbooks/argocd.yml`
- `ansible/roles/argocd/tasks/main.yml`
- `kubernetes/argocd/apps/` — définitions des Applications
- Mot de passe admin dans `ansible/inventory/group_vars/all/vault.yml`
