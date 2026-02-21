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
| Secrets (K8s) | SOPS + age (KSOPS) |
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
make secret-create APP=<nom>   # Créer un nouveau secret chiffré
make secret-edit APP=<nom>     # Éditer un secret existant
make secret-view APP=<nom>     # Afficher un secret en clair
```

### Port-forwards et VPS

```bash
make vps           # Afficher les PV et le stockage du VPS
make pf-argocd     # Port-forward ArgoCD → https://argocd.localhost
make pf-grafana    # Port-forward Grafana → https://grafana.localhost
make pf-all        # Lancer tous les port-forwards
make pf-ls         # Lister les port-forwards actifs
make pf-down       # Stopper tous les port-forwards
```

### Ansible (`cd ansible/`)

```bash
make ping          # Tester la connexion
make bootstrap     # Sécurité : SSH, UFW, fail2ban, mises à jour auto
make k3s           # Installer k3s + Ingress NGINX + cert-manager
make registry      # Docker Registry self-hosted
make registry-ui   # Interface web du Registry
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
- Secrets K8s chiffrés via SOPS + age (KSOPS)
- kubectl via SSH tunnel uniquement

## SOPS + age — Gérer les secrets

Les secrets sont chiffrés dans Git via SOPS + age, et déchiffrés automatiquement par ArgoCD via KSOPS.

```bash
make secret-create APP=mon-app   # Créer un nouveau secret chiffré
make secret-edit APP=mon-app     # Éditer un secret existant
make secret-view APP=mon-app     # Afficher un secret en clair
```

Voir [docs/10-secrets.md](docs/10-secrets.md) pour le détail du workflow.

## Storage

Les données applicatives sont stockées dans `/opt/k3s-data/` sur le VPS (configuré via le rôle Ansible `k3s`).

Le `local-path-provisioner` de k3s provisionne automatiquement les nouveaux PVCs dans ce répertoire. Les PVCs existants (monitoring, registry) restent dans `/var/lib/rancher/k3s/storage/`.

```bash
make vps    # Voir les PV et le contenu de /opt/k3s-data/
```

Le playbook `ansible/playbooks/migrate-pvc.yml` permet de migrer des PVCs existants vers `/opt/k3s-data/` (suspend ArgoCD, backup, supprime/recrée les PVCs, restaure les données).

## Documentation

Voir le dossier [docs/](docs/) pour le guide étape par étape.
