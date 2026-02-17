# Étape 1 — Ansible Bootstrap du serveur

## Prérequis

- Ansible installé sur ton Mac (`brew install ansible`)
- Accès SSH root au serveur o2s

## Inventory

Fichier `ansible/inventory/hosts.yml` :

```yaml
all:
  hosts:
    o2s:
      ansible_host: 109.234.167.177
      ansible_user: root
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519  # adapter selon ta clé
```

## Ce que fait le playbook bootstrap

### 1. Créer un user non-root

- Créer un user `deploy` avec accès sudo
- Copier ta clé SSH publique
- Désactiver le login root SSH après coup

### 2. Sécuriser SSH

- Désactiver `PasswordAuthentication`
- Désactiver `PermitRootLogin` (après création du user deploy)
- Changer le port SSH (optionnel mais recommandé)

### 3. Firewall

Avec `ufw` :

```
22/tcp    — SSH
80/tcp    — HTTP (redirect vers HTTPS)
443/tcp   — HTTPS
6443/tcp  — API Kubernetes (restreindre à ton IP si possible)
```

### 4. fail2ban

- Installer et configurer pour SSH
- Ban après 5 tentatives, ban de 1h

### 5. Mises à jour automatiques

- `unattended-upgrades` pour les patches de sécurité

### 6. Paquets de base

- `curl`, `wget`, `git`, `htop`, `jq`

## Commandes

```bash
# Tester la connexion
ansible -i ansible/inventory/hosts.yml all -m ping

# Lancer le bootstrap
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/bootstrap.yml
```

## Vérification

Après le bootstrap :

```bash
# Se connecter avec le nouveau user
ssh deploy@109.234.167.177

# Vérifier sudo
sudo whoami  # → root

# Vérifier le firewall
sudo ufw status

# Vérifier fail2ban
sudo fail2ban-client status sshd
```

## Fichiers à créer

- `ansible/playbooks/bootstrap.yml`
- `ansible/roles/common/tasks/main.yml` — user, paquets de base
- `ansible/roles/security/tasks/main.yml` — SSH hardening, firewall, fail2ban
