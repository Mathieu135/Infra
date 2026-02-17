# Comprendre Ansible et k3s

Guide de référence sur le fonctionnement des deux outils principaux de l'infra.

---

## Ansible — Automatisation de serveurs

### C'est quoi

Ansible est un outil qui exécute des commandes sur des serveurs distants via SSH.
Pas d'agent à installer sur le serveur — il se connecte, exécute, et c'est fini.

### Concepts clés

| Concept | Description | Exemple dans le projet |
|---------|-------------|----------------------|
| **Inventory** | Liste des serveurs cibles | `ansible/inventory/hosts.yml` |
| **Playbook** | Fichier YAML qui décrit quoi faire | `ansible/playbooks/bootstrap.yml` |
| **Role** | Bloc réutilisable de tâches | `ansible/roles/k3s/tasks/main.yml` |
| **Task** | Une action unitaire (installer un paquet, copier un fichier...) | `apt: name: curl state: present` |
| **Handler** | Action déclenchée par un `notify` (ex: restart d'un service) | `notify: restart sshd` |
| **Vault** | Chiffrement des secrets | `ansible/inventory/group_vars/all/vault.yml` |

### Comment ça marche

```
ansible-playbook playbooks/bootstrap.yml
                     │
                     ▼
            Lit l'inventory (hosts.yml)
            → Cible : vps (91.134.142.175)
                     │
                     ▼
            Lit le playbook
            → Roles : common, security
                     │
                     ▼
            Se connecte en SSH au VPS
                     │
                     ▼
            Exécute chaque task dans l'ordre
            1. apt update
            2. apt install curl, git, htop...
            3. Configurer SSH (désactiver root, password)
            4. Configurer UFW (deny all, allow 22/80/443)
            5. Installer fail2ban
                     │
                     ▼
            Si un handler est notifié → l'exécute à la fin
            (ex: restart sshd après modif de sshd_config)
```

### Fichiers du projet

```
ansible/
├── ansible.cfg                         ← Config globale (vault password file, roles path)
├── Makefile                            ← Raccourcis : make bootstrap, make k3s, etc.
├── inventory/
│   ├── hosts.yml                       ← IP du VPS, user SSH, variables globales
│   └── group_vars/all/vault.yml        ← Secrets chiffrés (registre, email Let's Encrypt)
├── playbooks/
│   ├── bootstrap.yml                   ← Sécurité + paquets de base
│   ├── k3s.yml                         ← Install k3s + Helm + Ingress + cert-manager
│   ├── registry.yml                    ← Docker Registry (Helm)
│   ├── registry-ui.yml                 ← UI web du registry
│   ├── argocd.yml                      ← ArgoCD (Helm)
│   ├── sealed-secrets.yml              ← Sealed Secrets (Helm)
│   └── reset.yml                       ← Désinstaller k3s (danger)
└── roles/
    ├── common/tasks/main.yml           ← apt update, install paquets
    ├── security/tasks/main.yml         ← SSH hardening, UFW, fail2ban
    ├── k3s/tasks/main.yml              ← Install k3s, kubeconfig, Helm
    ├── ingress/tasks/main.yml          ← Ingress NGINX, cert-manager, ClusterIssuer
    ├── registry/tasks/main.yml         ← Docker Registry Helm + Ingress basic-auth
    ├── registry-ui/tasks/main.yml      ← Registry UI Helm
    ├── argocd/tasks/main.yml           ← ArgoCD Helm
    └── sealed-secrets/tasks/main.yml   ← Sealed Secrets Helm
```

### Commandes courantes

```bash
# Depuis le dossier ansible/

# Tester la connexion SSH
make ping

# Provisionner le serveur de zéro (sécurité + paquets)
make bootstrap

# Installer k3s + ingress + cert-manager
make k3s

# Installer un composant spécifique
make registry
make argocd
make sealed-secrets

# Dry-run (voir ce qui changerait sans appliquer)
make check-bootstrap
make check-k3s

# Tout relancer (idempotent — ne refait que ce qui a changé)
make all

# Gérer les secrets Ansible Vault
ansible-vault edit inventory/group_vars/all/vault.yml
ansible-vault view inventory/group_vars/all/vault.yml
```

### Idempotence

Ansible est **idempotent** : relancer un playbook ne casse rien.
Si un paquet est déjà installé, il ne le réinstalle pas.
Si k3s tourne déjà, il ne le réinstalle pas (vérifie avec `stat`).

Exemple dans `roles/k3s/tasks/main.yml` :
```yaml
- name: Vérifier si k3s est déjà installé
  stat:
    path: /usr/local/bin/k3s
  register: k3s_binary

- name: Installer k3s
  shell: curl -sfL https://get.k3s.io | sh -s - --disable traefik
  when: not k3s_binary.stat.exists    # ← ne s'exécute que si absent
```

### Ansible Vault

Les secrets (passwords, emails) sont chiffrés dans `vault.yml` et déchiffrés automatiquement au runtime grâce au fichier `.vault_password` (non commité).

```bash
# Éditer les secrets
ansible-vault edit inventory/group_vars/all/vault.yml

# Utilisation dans les playbooks via les variables
# hosts.yml :  registry_user: "{{ vault_registry_user }}"
# vault.yml :  vault_registry_user: monuser
```

---

## k3s — Kubernetes léger

### C'est quoi

k3s est une distribution Kubernetes certifiée, packagée en un seul binaire (~70 MB).
Conçue pour les VPS, Raspberry Pi, edge — partout où un cluster K8s complet serait trop lourd.

### Différences avec Kubernetes classique

| | k3s | Kubernetes (kubeadm) |
|---|---|---|
| Installation | 1 commande (`curl ... \| sh`) | Multiples étapes, pré-requis |
| RAM | ~512 MB | ~2 GB minimum |
| Base de données | SQLite (single-node) | etcd (cluster) |
| Ingress par défaut | Traefik (désactivé ici) | Aucun |
| Binaire | 1 seul (~70 MB) | Multiples composants |

### Architecture sur notre VPS

```
VPS (91.134.142.175)
│
├── k3s server (PID 1-ish)
│   ├── API Server          ← kubectl parle ici (port 6443)
│   ├── Scheduler           ← Décide où lancer les pods
│   ├── Controller Manager  ← Réconcilie l'état désiré vs réel
│   └── SQLite              ← Stocke l'état du cluster
│
├── kubelet                 ← Gère les pods sur ce node
├── containerd              ← Runtime de containers (remplace Docker)
│
└── Pods système (kube-system)
    ├── coredns              ← DNS interne du cluster
    ├── metrics-server       ← Métriques CPU/RAM
    └── local-path-provisioner ← PersistentVolumes automatiques
```

### Concepts Kubernetes essentiels

| Concept | Description | Exemple |
|---------|-------------|---------|
| **Pod** | Plus petite unité — 1 ou plusieurs containers | Le container nginx du frontend |
| **Deployment** | Gère les pods (replicas, rolling update) | `deployment-frontend.yaml` |
| **Service** | IP stable pour accéder aux pods | `service-frontend.yaml` (port 80) |
| **Ingress** | Routing HTTP externe (host/path → service) | `ingress.yaml` (matltz.dev → frontend) |
| **Namespace** | Isolation logique des resources | `portfolio`, `registry`, `argocd` |
| **PVC** | Stockage persistant pour les pods | `pvc.yaml` (1Gi pour SQLite) |
| **Secret** | Données sensibles (mots de passe, tokens) | `sealed-secret.yaml` |
| **CronJob** | Tâche planifiée | `cleanup-cronjob.yaml` (dimanche 3h) |
| **ConfigMap** | Configuration non-sensible | Config du registry |

### Flux d'une requête HTTP

```
Utilisateur tape matltz.dev
        │
        ▼
Cloudflare DNS → 91.134.142.175
        │
        ▼
Ingress NGINX (écoute :80/:443)
        │ Lit les règles Ingress :
        │   matltz.dev     → service portfolio-frontend:80
        │   argocd.matltz.dev → service argocd-server:443
        ▼
Service (ClusterIP)
        │ Répartit vers les pods
        ▼
Pod (container nginx ou express)
```

### Commandes kubectl courantes

```bash
# Prérequis : tunnel SSH actif
# Terminal 1 :
make tunnel   # ssh -N -L 26443:127.0.0.1:6443 vps

# --- Voir l'état du cluster ---
kubectl get nodes                          # Nodes du cluster
kubectl get pods -A                        # Tous les pods, tous les namespaces
kubectl get pods -n portfolio              # Pods du namespace portfolio
kubectl get svc -n portfolio               # Services
kubectl get ingress -n portfolio           # Ingress (routing HTTP)

# --- Debugging ---
kubectl describe pod <nom> -n portfolio    # Détails d'un pod (events, état)
kubectl logs <nom> -n portfolio            # Logs d'un container
kubectl logs <nom> -n portfolio -f         # Logs en temps réel (follow)
kubectl logs <nom> -n portfolio --previous # Logs du container précédent (crash)

# --- Opérations ---
kubectl delete pod <nom> -n portfolio      # Tuer un pod (le Deployment en recrée un)
kubectl rollout restart deploy/portfolio-frontend -n portfolio  # Redémarrer un déploiement
kubectl scale deploy/portfolio-frontend -n portfolio --replicas=2  # Scaler

# --- Secrets et configs ---
kubectl get secrets -n portfolio           # Lister les secrets
kubectl get configmap -n portfolio         # Lister les configmaps

# --- Appliquer des manifests manuellement ---
kubectl apply -f fichier.yaml              # Créer/mettre à jour une resource
kubectl delete -f fichier.yaml             # Supprimer une resource

# --- Helm (gestion des charts) ---
helm list -A                               # Toutes les releases Helm installées
helm status registry -n registry           # Statut d'une release
helm history argocd -n argocd              # Historique des versions
```

### Accès au cluster depuis le Mac

Le port 6443 (API k3s) est bloqué par UFW sauf depuis `127.0.0.1`.
On passe par un tunnel SSH qui mappe le port local 26443 au port 6443 du VPS :

```
Mac (kubectl :26443) ──SSH──▶ VPS (127.0.0.1:6443) ──▶ API k3s
```

```bash
# Ouvrir le tunnel
make tunnel   # = ssh -N -L 26443:127.0.0.1:6443 vps

# kubectl utilise le kubeconfig qui pointe vers 127.0.0.1:26443
kubectl get nodes
```

### Stockage (PersistentVolumes)

k3s inclut `local-path-provisioner` : quand un pod demande du stockage via un PVC,
k3s crée automatiquement un dossier sur le disque du node.

```yaml
# Le pod demande 1Gi
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: portfolio-data
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
# → k3s crée /var/lib/rancher/k3s/storage/pvc-xxx-xxx/
```

### Ajouter un node (multi-node)

Si un jour on passe en multi-node :

```bash
# Sur le VPS principal — récupérer le token
sudo cat /var/lib/rancher/k3s/server/node-token

# Sur le nouveau VPS — joindre le cluster
curl -sfL https://get.k3s.io | K3S_URL=https://91.134.142.175:6443 K3S_TOKEN=<token> sh -
```

---

## Résumé : qui fait quoi

| Action | Outil | Fréquence |
|--------|-------|-----------|
| Installer k3s | Ansible | Une fois |
| Installer ArgoCD, Registry | Ansible | Une fois |
| Upgrader un composant Helm | Ansible | Occasionnel |
| Déployer une app | ArgoCD (GitOps) | À chaque push |
| Scaler, debug, logs | kubectl | Ad hoc |
| Gérer les secrets | kubeseal + kubectl | Quand nécessaire |
