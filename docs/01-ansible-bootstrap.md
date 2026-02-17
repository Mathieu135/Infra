# Étape 1 — Ansible Bootstrap du serveur

> **Statut : DONE** — Bootstrap appliqué et vérifié sur le VPS.

## Prérequis

- Ansible installé sur ton Mac (`brew install ansible`)
- Accès SSH au VPS OVH (user `ubuntu`)

## Inventory

Fichier `ansible/inventory/hosts.yml` :

```yaml
all:
  hosts:
    vps:
      ansible_host: 91.134.142.175
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519  # adapter selon ta clé
```

## Ce que fait le playbook bootstrap

### 1. Sécuriser SSH ✅

- Désactiver `PasswordAuthentication`
- Désactiver `PermitRootLogin`

### 2. Firewall ✅

UFW actif, policy `deny` par défaut. Ports ouverts (IPv4 + IPv6) :

```
22/tcp    — SSH
80/tcp    — HTTP
443/tcp   — HTTPS
6443/tcp  — API Kubernetes
```

### 3. fail2ban ✅

- Installé et configuré pour SSH
- Ban après 5 tentatives, ban de 1h, findtime 10min

### 4. Mises à jour automatiques ✅

- `unattended-upgrades` activé (patches de sécurité auto)

### 5. Paquets de base ✅

- `curl`, `wget`, `git`, `htop`, `jq`

## Commandes

```bash
# Tester la connexion
make ping
# ou : ansible -i ansible/inventory/hosts.yml all -m ping

# Lancer le bootstrap
make bootstrap
# ou : ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/bootstrap.yml
```

## Vérification

Après le bootstrap :

```bash
# Se connecter
ssh vps

# Vérifier sudo
sudo whoami  # → root

# Vérifier le firewall
sudo ufw status

# Vérifier fail2ban
sudo fail2ban-client status sshd
```

## Fichiers

- `ansible/playbooks/bootstrap.yml`
- `ansible/roles/common/tasks/main.yml` — paquets de base
- `ansible/roles/security/tasks/main.yml` — SSH hardening, firewall, fail2ban
- `ansible/roles/security/handlers/main.yml` — restart sshd, fail2ban
