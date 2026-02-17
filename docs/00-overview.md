# Infra Perso — Vue d'ensemble

## Serveur

| Propriété | Valeur |
|-----------|--------|
| Nom | o2s |
| IP | 109.234.167.177 |
| Accès | SSH root |
| Usage | Projets personnels uniquement |

## Stack

| Couche | Outil | Rôle |
|--------|-------|------|
| Provisioning | Ansible | Bootstrap et maintenance du serveur |
| Kubernetes | k3s | Cluster single-node |
| GitOps | ArgoCD | Déploiement automatique depuis Git |
| Ingress | Traefik (inclus k3s) | Reverse proxy + routage |
| TLS | cert-manager + Let's Encrypt | HTTPS automatique |
| Registry | Docker Registry self-hosted | Stockage des images Docker |
| Secrets | Sealed Secrets | Secrets chiffrés dans Git |
| Monitoring | Prometheus + Grafana | Métriques et dashboards |
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

## Domaines (à configurer)

```
ton-domaine.com           → app principale (ou landing)
*.ton-domaine.com         → sous-domaines par projet
argocd.ton-domaine.com    → UI ArgoCD
registry.ton-domaine.com  → Docker Registry
grafana.ton-domaine.com   → Dashboards monitoring
```

## Étapes de mise en place

1. [Ansible bootstrap](01-ansible-bootstrap.md)
2. [Installer k3s](02-k3s.md)
3. [cert-manager + Let's Encrypt](03-cert-manager.md)
4. [Docker Registry](04-registry.md)
5. [ArgoCD](05-argocd.md)
6. [Sealed Secrets](06-sealed-secrets.md)
7. [Premier projet test](07-premier-projet.md)
8. [Monitoring](08-monitoring.md)
9. [Onboarder un projet](09-onboarding-projet.md)
