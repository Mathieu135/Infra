# Étape 7 — Premier projet (Portfolio)

> **Statut : DONE** — Portfolio déployé sur `https://matltz.dev`. Vérifié le 2026-02-17.

## Pipeline

```
git push → GitHub Actions (build frontend + backend en parallèle) → push registry → update tags infra → ArgoCD → k3s
```

## Ce qui a été fait

### 1. Repo projet (`Mathieu135/MonPortefolio`)

- [x] **Dockerfile** multi-stage à la racine (targets `frontend` et `backend`)
- [x] **nginx.conf** avec proxy `/api` et `/uploads` vers le backend (interne)
- [x] **GitHub Actions** `.github/workflows/deploy.yaml` (builds parallélisés)
- [x] **Secrets GitHub** configurés : `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `INFRA_PAT`
- [x] **package-lock.json** trackés (frontend + backend) pour `npm ci`

### 2. Repo infra

- [x] **Manifests K8s** dans `kubernetes/apps/portfolio/`
  - `deployment-frontend.yaml` — nginx servant le build React
  - `deployment-backend.yaml` — Express + SQLite avec PVCs
  - `service-frontend.yaml` — port 80
  - `service-backend.yaml` — port 3001 (interne uniquement)
  - `ingress.yaml` — `matltz.dev` avec TLS Let's Encrypt
  - `pvc.yaml` — 1Gi data (SQLite) + 2Gi uploads
  - `secrets.enc.yaml` — JWT_SECRET chiffré avec SOPS + age
  - `ksops-generator.yaml` — générateur KSOPS pour déchiffrement ArgoCD
  - `kustomization.yaml`
- [x] **Application ArgoCD** dans `kubernetes/argocd/apps/portfolio.yaml`

### 3. DNS

- [x] `matltz.dev` → `91.134.142.175` (Cloudflare, DNS only)

### 4. Cluster (une seule fois)

- [x] Repo infra connecté à ArgoCD (deploy key SSH)
- [x] `registry-credentials` créé dans le namespace `portfolio`
- [x] Application ArgoCD appliquée (`kubectl apply -f kubernetes/argocd/apps/portfolio.yaml`)

## Checklist de validation

- [x] Push sur MonPortefolio → GitHub Actions se lance
- [x] Images frontend + backend buildées et pushées sur `registry.matltz.dev`
- [x] Tags mis à jour dans le repo infra (commit automatique)
- [x] ArgoCD détecte le changement et sync
- [x] Pods running sur k3s
- [x] `https://matltz.dev` accessible
- [x] Certificat TLS valide (Let's Encrypt)

## Architecture

```
Internet → Ingress NGINX (TLS) → portfolio-frontend (nginx:80)
                                       ├── / → fichiers statiques React
                                       ├── /api → proxy → portfolio-backend:3001
                                       └── /uploads → proxy → portfolio-backend:3001
```

Le backend n'est pas exposé publiquement, uniquement accessible via le proxy nginx du frontend.

## Fichiers

- `kubernetes/apps/portfolio/` — manifests K8s
- `kubernetes/argocd/apps/portfolio.yaml` — app ArgoCD
