# Infra

Infrastructure personnelle sur VPS OVH (k3s single-node).

## Stack

| Couche | Outil |
|--------|-------|
| Provisioning | Ansible |
| Kubernetes | k3s |
| Ingress | Ingress NGINX |
| TLS | cert-manager + Let's Encrypt |
| Registry | Docker Registry self-hosted |
| Secrets (Ansible) | Ansible Vault |
| Secrets (K8s) | Sealed Secrets (kubeseal) |
| GitOps | ArgoCD |
| DNS | Cloudflare |

## Structure

```
ansible/                  # Provisioning et configuration
  inventory/hosts.yml     # Inventaire + variables
  playbooks/              # Playbooks Ansible
  roles/                  # Rôles (common, security, k3s, ingress, registry, registry-ui)
kubernetes/               # Manifests K8s (ArgoCD, apps, monitoring...)
docs/                     # Documentation par étape
```

## Prérequis

- Ansible (`brew install ansible`)
- kubectl (`brew install kubectl`)
- Accès SSH au VPS (alias `vps` dans `~/.ssh/config`)
- Fichier `ansible/.vault_password` (non versionné)

## Commandes

### Racine du projet

```bash
make tunnel    # Tunnel SSH pour kubectl local (port 6443)
make ssh       # Connexion SSH au VPS
make kubeseal IN=<secret.yaml> OUT=<sealed-secret.yaml>  # Chiffrer un secret K8s
```

### Ansible (`cd ansible/`)

```bash
make ping          # Tester la connexion
make bootstrap     # Sécurité : SSH, UFW, fail2ban, mises à jour auto
make k3s           # Installer k3s + Ingress NGINX + cert-manager
make registry      # Docker Registry self-hosted
make registry-ui   # Interface web du Registry
make sealed-secrets # Sealed Secrets (kubeseal)
make all           # Tout lancer dans l'ordre
make check         # Dry-run de tous les playbooks
```

## Domaines

Tous les enregistrements DNS pointent vers `91.134.142.175` (Cloudflare, DNS only).

| Domaine | Service |
|---------|---------|
| `matltz.dev` | Portfolio + blog (React + Express) |
| `argocd.matltz.dev` | ArgoCD |
| `registry.matltz.dev` | Docker Registry + UI |

## Sécurité

- SSH : clé uniquement, pas de root
- UFW : deny par défaut, ports 22/80/443 ouverts, 6443 restreint à localhost
- fail2ban : SSH (5 tentatives, ban 1h)
- Auth basic-auth sur les ingress exposés
- Rate limiting (10 req/s) sur les ingress
- Secrets dans Ansible Vault (chiffrés AES-256)
- Secrets K8s chiffrés via Sealed Secrets (kubeseal)
- kubectl via SSH tunnel uniquement

## Sealed Secrets — Chiffrer un secret

```bash
# 1. Créer le secret en clair (ne jamais commiter)
kubectl create secret generic mon-secret \
  --namespace mon-app \
  --from-literal=DATABASE_URL=postgres://user:pass@host/db \
  --dry-run=client -o yaml > /tmp/secret.yaml

# 2. Chiffrer (ouvre un tunnel SSH, chiffre, ferme le tunnel, supprime le clair)
make kubeseal IN=/tmp/secret.yaml OUT=kubernetes/apps/mon-app/sealed-secret.yaml

# 3. Commiter le SealedSecret (chiffré, safe dans Git)
git add kubernetes/apps/mon-app/sealed-secret.yaml
```

ArgoCD sync le `SealedSecret` → le controller le déchiffre en `Secret` → disponible pour les pods.

## Documentation

Voir le dossier [docs/](docs/) pour le guide étape par étape.
