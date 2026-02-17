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
| Secrets | Ansible Vault |
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
| `matltz.dev` | Portfolio + blog |
| `registry.matltz.dev` | Docker Registry |
| `registry-ui.matltz.dev` | Interface web du Registry |

## Sécurité

- SSH : clé uniquement, pas de root
- UFW : deny par défaut, ports 22/80/443 ouverts, 6443 restreint à localhost
- fail2ban : SSH (5 tentatives, ban 1h)
- Auth basic-auth sur les ingress exposés
- Rate limiting (10 req/s) sur les ingress
- Secrets dans Ansible Vault (chiffrés AES-256)
- kubectl via SSH tunnel uniquement

## Documentation

Voir le dossier [docs/](docs/) pour le guide étape par étape.
