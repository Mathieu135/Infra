# Infra Perso — Vue d'ensemble

## Serveur

| Propriété | Valeur |
|-----------|--------|
| Nom | vps |
| IP | 91.134.142.175 |
| Hébergeur | OVH VPS |
| Domaine | matltz.dev (Cloudflare) |
| DNS | Cloudflare |
| Accès | SSH ubuntu |
| Usage | Projets personnels uniquement |

## Stack

| Couche | Outil | Rôle |
|--------|-------|------|
| Provisioning | Ansible | Bootstrap et maintenance du serveur |
| Kubernetes | k3s | Cluster single-node |
| GitOps | ArgoCD | Déploiement automatique depuis Git |
| Ingress | Ingress NGINX | Reverse proxy + routage |
| TLS | cert-manager + Let's Encrypt | HTTPS automatique |
| Registry | Docker Registry self-hosted | Stockage des images Docker |
| Secrets Ansible | Ansible Vault | Variables sensibles chiffrées |
| Secrets K8s | SOPS + age | Secrets chiffrés dans Git (KSOPS) |
| Monitoring | Prometheus + Grafana | Métriques et dashboards |
| Logs | Loki + Promtail | Collecte et query des logs |
| Network | NetworkPolicies | Isolation réseau des namespaces |
| CI | GitHub Actions | Build et push des images |

## Repos

| Repo | Contenu |
|------|---------|
| `infra` (celui-ci) | Ansible + manifests K8s + docs |
| Chaque projet | Code + Dockerfile + GitHub Actions |

## Architecture

```
GitHub push
  → GitHub Actions : build image + push registry
  → Met à jour le tag dans infra/kubernetes/apps/
  → ArgoCD détecte le changement
  → Deploy sur k3s
```

## Domaines

Registrar : **Cloudflare** — DNS géré par Cloudflare.

```
matltz.dev                → portfolio + blog
registry.matltz.dev       → Docker Registry + UI (auth basic)
```

### Accès internes (port-forward)

```bash
# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:80
# → http://localhost:8080

# Grafana
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
# → http://localhost:3000
```

## Structure du repo

### `ansible/` — Provisioning (one-shot)

```
ansible/
├── inventory/hosts.yml                 ← IP du VPS + user SSH
├── inventory/group_vars/all/vault.yml  ← Secrets chiffrés (ansible-vault)
├── playbooks/                          ← Point d'entrée par composant
│   ├── bootstrap.yml                   ← Packages de base, sécurité, UFW
│   ├── k3s.yml                         ← Install k3s
│   ├── registry.yml                    ← Docker Registry (Helm + Ingress)
│   ├── registry-ui.yml                 ← UI pour le registry
│   └── argocd.yml                      ← ArgoCD (Helm)
├── roles/                              ← Logique de chaque composant
│   ├── common/tasks/main.yml
│   ├── k3s/tasks/main.yml
│   └── ...
└── Makefile                            ← `make bootstrap`, `make k3s`, etc.
```

Ansible se connecte en SSH au VPS et installe les composants via Helm.
C'est du **one-shot** — lancé une fois pour provisionner, ou pour upgrader.
Chaque rôle = un composant infra (k3s, registry, argocd...).

### `kubernetes/` — Manifests GitOps (continu)

```
kubernetes/
├── apps/                           ← Manifests des projets déployés
│   └── portfolio/
│       ├── kustomization.yaml      ← Liste des resources
│       ├── deployment-*.yaml       ← Pods frontend/backend
│       ├── service-*.yaml          ← Services internes
│       ├── ingress.yaml            ← Routing externe (TLS)
│       ├── pvc.yaml                ← Stockage persistant
│       ├── network-policy.yaml     ← NetworkPolicies (isolation réseau)
│       ├── secrets.enc.yaml        ← Secrets chiffrés (SOPS/age)
│       └── ksops-generator.yaml    ← Générateur KSOPS pour Kustomize
├── argocd/apps/                    ← Applications ArgoCD
│   ├── portfolio.yaml              ← Pointe vers kubernetes/apps/portfolio
│   ├── monitoring-dashboards.yaml  ← Pointe vers kubernetes/monitoring
│   ├── registry-maintenance.yaml   ← Pointe vers kubernetes/registry
│   └── argocd-policies.yaml        ← Pointe vers kubernetes/argocd-policies
├── argocd-policies/                ← NetworkPolicies du namespace argocd
│   └── network-policy.yaml
├── monitoring/                     ← Dashboards, alertes, NetworkPolicies
│   ├── dashboard-*.yaml
│   ├── service-monitor-generic.yaml
│   ├── prometheus-rules.yaml
│   └── network-policy.yaml
└── registry/                       ← CronJobs de maintenance + NetworkPolicies
    ├── cleanup-cronjob.yaml
    ├── gc-cronjob.yaml
    └── network-policy.yaml
```

ArgoCD surveille ce dossier sur GitHub. Quand un fichier change (ex: CI met à jour un tag d'image), ArgoCD le détecte et applique automatiquement sur le cluster. C'est du **GitOps continu**.

### Lien entre les deux

```
Ansible (one-shot)              Kubernetes (continu)
━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━━━━━
Installe k3s              →     Le cluster tourne
Installe ArgoCD           →     ArgoCD surveille kubernetes/
Installe Registry         →     CI push les images
                                ArgoCD déploie les apps
```

Ansible pose l'infra, ensuite tout passe par Git + ArgoCD.

## Étapes de mise en place

1. [Ansible bootstrap](01-ansible-bootstrap.md)
2. [Installer k3s](02-k3s.md)
3. [cert-manager + Let's Encrypt](03-cert-manager.md)
4. [Docker Registry](04-registry.md)
5. [ArgoCD](05-argocd.md)
6. [Connexion au VPS](06-connexion-vps.md)
7. [Premier projet test](07-premier-projet.md)
8. [Monitoring](08-monitoring.md)
9. [Onboarder un projet](09-onboarding-projet.md)
10. [SOPS + age (KSOPS)](10-secrets.md)
11. [Comprendre Ansible et k3s](10-comprendre-ansible-et-k3s.md)
12. [NetworkPolicies](11-network-policies.md)
