# Étape 7 — Premier projet test

## Objectif

Déployer une app simple pour valider tout le pipeline de bout en bout :

```
git push → GitHub Actions → build image → push registry → update tag → ArgoCD → k3s
```

## 1. App de test

Une app minimale (ex: nginx avec une page custom, ou une petite API) :

```dockerfile
# Dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
```

```html
<!-- index.html -->
<!DOCTYPE html>
<html>
<body><h1>Hello from k3s!</h1></body>
</html>
```

## 2. GitHub Actions — Build & Push

```yaml
# .github/workflows/deploy.yaml
name: Build & Deploy

on:
  push:
    branches: [main]

env:
  REGISTRY: registry.ton-domaine.com
  IMAGE_NAME: test-app

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
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

      - name: Update infra repo
        uses: actions/checkout@v4
        with:
          repository: ton-user/infra
          token: ${{ secrets.INFRA_PAT }}
          path: infra

      - name: Update image tag
        run: |
          cd infra
          sed -i "s|image:.*|image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|" kubernetes/apps/test-app/deployment.yaml
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "deploy: test-app ${{ github.sha }}"
          git push
```

### Secrets GitHub à configurer

Dans le repo du projet → Settings → Secrets :

| Secret | Valeur |
|--------|--------|
| `REGISTRY_USERNAME` | Ton user htpasswd du registry |
| `REGISTRY_PASSWORD` | Ton password htpasswd |
| `INFRA_PAT` | Personal Access Token GitHub avec accès au repo infra |

## 3. Manifests Kubernetes

```yaml
# kubernetes/apps/test-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      imagePullSecrets:
        - name: registry-credentials
      containers:
        - name: test-app
          image: registry.ton-domaine.com/test-app:latest
          ports:
            - containerPort: 80
```

```yaml
# kubernetes/apps/test-app/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: test-app
spec:
  selector:
    app: test-app
  ports:
    - port: 80
      targetPort: 80
```

```yaml
# kubernetes/apps/test-app/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
  namespace: test-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - test.ton-domaine.com
      secretName: test-app-tls
  rules:
    - host: test.ton-domaine.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: test-app
                port:
                  number: 80
```

```yaml
# kubernetes/apps/test-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

## 4. Application ArgoCD

```yaml
# kubernetes/argocd/apps/test-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:ton-user/infra.git
    targetRevision: main
    path: kubernetes/apps/test-app
  destination:
    server: https://kubernetes.default.svc
    namespace: test-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 5. Checklist de validation

- [ ] Push sur le repo test → GitHub Actions se lance
- [ ] Image buildée et pushée sur `registry.ton-domaine.com`
- [ ] Tag mis à jour dans le repo infra
- [ ] ArgoCD détecte le changement et sync
- [ ] Pod running sur k3s
- [ ] `https://test.ton-domaine.com` affiche "Hello from k3s!"
- [ ] Certificat TLS valide (Let's Encrypt)

## Fichiers à créer

- `kubernetes/apps/test-app/deployment.yaml`
- `kubernetes/apps/test-app/service.yaml`
- `kubernetes/apps/test-app/ingress.yaml`
- `kubernetes/apps/test-app/kustomization.yaml`
- `kubernetes/argocd/apps/test-app.yaml`
