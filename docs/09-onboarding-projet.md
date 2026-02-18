# Étape 9 — Onboarder un nouveau projet

## Checklist rapide

### 1. Repo du projet

- [ ] **Dockerfile** multi-stage à la racine avec targets nommés
- [ ] **GitHub Actions** `.github/workflows/deploy.yaml`
- [ ] **Secrets GitHub** : `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `INFRA_PAT`
- [ ] **package-lock.json** (ou équivalent) commité pour builds reproductibles

### 2. Repo infra

- [ ] **Manifests K8s** dans `kubernetes/apps/<nom-projet>/`
  - `deployment.yaml` (ou split frontend/backend)
  - `service.yaml`
  - `ingress.yaml`
  - `kustomization.yaml`
  - `sealed-secret.yaml` (si secrets nécessaires)
  - `pvc.yaml` (si stockage persistant)
- [ ] **Application ArgoCD** dans `kubernetes/argocd/apps/<nom-projet>.yaml`

### 3. DNS (Cloudflare)

- [ ] Enregistrement A `<nom-projet>.matltz.dev` → `91.134.142.175` (DNS only, pas proxied)

### 4. Cluster (une seule fois par projet)

- [ ] `registry-credentials` dans le namespace :
```bash
kubectl create secret docker-registry registry-credentials \
  --namespace <nom-projet> \
  --docker-server=registry.matltz.dev \
  --docker-username=USER --docker-password=PASS
```
- [ ] Sealed secret si nécessaire :
```bash
kubectl create secret generic <nom-projet>-secrets \
  --namespace <nom-projet> \
  --from-literal=CLE=VALEUR \
  --dry-run=client -o yaml > /tmp/secret.yaml
make kubeseal IN=/tmp/secret.yaml OUT=kubernetes/apps/<nom-projet>/sealed-secret.yaml
```
- [ ] Appliquer l'app ArgoCD :
```bash
kubectl apply -f kubernetes/argocd/apps/<nom-projet>.yaml
```

## Templates

### Dockerfile (multi-stage)

```dockerfile
# ---- Build ----
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---- Prod ----
FROM nginx:alpine AS frontend
COPY --from=build /app/dist /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### GitHub Actions (builds parallélisés)

```yaml
name: Build & Deploy

on:
  push:
    branches: [main]

env:
  REGISTRY: registry.matltz.dev
  IMAGE_NAME: NOM_PROJET

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          target: frontend
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

  deploy:
    needs: [build]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: Mathieu135/infra
          token: ${{ secrets.INFRA_PAT }}

      - name: Update image tag
        run: |
          sed -i "s|image: registry.matltz.dev/NOM_PROJET:.*|image: registry.matltz.dev/NOM_PROJET:${{ github.sha }}|" kubernetes/apps/NOM_PROJET/deployment.yaml
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "deploy: NOM_PROJET ${{ github.sha }}"
          git push
```

### Application ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: NOM_PROJET
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:Mathieu135/infra.git
    targetRevision: main
    path: kubernetes/apps/NOM_PROJET
  destination:
    server: https://kubernetes.default.svc
    namespace: NOM_PROJET
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 5. Monitoring (automatique)

Si l'app expose des métriques Prometheus (`GET /metrics`), deux conditions :

1. Le port du Service est nommé `http`
2. Le Service porte le label `monitoring: "true"`

```yaml
metadata:
  labels:
    monitoring: "true"
spec:
  ports:
    - name: http
      port: 3000
      targetPort: 3000
```

C'est tout. Le ServiceMonitor générique scrape automatiquement les Services labellisés, les dashboards Grafana et les alertes s'appliquent à tous les namespaces.

Voir [étape 8](08-monitoring.md) pour les détails.

### 6. Logs (automatique)

Les logs stdout sont collectés automatiquement par Promtail. Pour que les dashboards fonctionnent correctement, l'app doit logger en **JSON** avec ces champs :

| Champ | Type | Description |
|---|---|---|
| `level` | string | `info`, `warn`, `error` (obligatoire) |
| `msg` | string | Message du log |
| `ts` | string | Timestamp ISO 8601 / RFC 3339 |

Champs optionnels pour les requêtes HTTP :

| Champ | Type | Description |
|---|---|---|
| `method` | string | `GET`, `POST`, etc. |
| `path` | string | `/api/users` |
| `status` | number | Code HTTP |
| `duration_ms` | number | Durée en ms |

Exemple de ligne de log :
```json
{"level":"info","msg":"request completed","ts":"2025-01-15T10:30:00Z","method":"GET","path":"/api/health","status":200,"duration_ms":3}
```

Les logs `debug` sont automatiquement droppés en production.

## Résumé

1. Dockerfile + GitHub Actions dans le repo projet
2. Manifests + app ArgoCD dans le repo infra
3. DNS Cloudflare (A record, DNS only)
4. `registry-credentials` + sealed secret + `kubectl apply` de l'app ArgoCD
5. Label `monitoring: "true"` sur le Service (si métriques)
6. Push → déploiement automatique
