# Étape 9 — Onboarder un nouveau projet

## Checklist pour chaque nouveau projet

### 1. Dans le repo du projet

- [ ] **Dockerfile** à la racine
- [ ] **GitHub Actions** workflow `.github/workflows/deploy.yaml`
- [ ] **Secrets GitHub** configurés : `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `INFRA_PAT`

### 2. Dans le repo infra

- [ ] **Manifests K8s** dans `kubernetes/apps/<nom-projet>/`
  - `deployment.yaml`
  - `service.yaml`
  - `ingress.yaml`
  - `kustomization.yaml`
  - `sealed-secret.yaml` (si le projet a des secrets)
- [ ] **Application ArgoCD** dans `kubernetes/argocd/apps/<nom-projet>.yaml`
- [ ] **DNS** : ajouter l'enregistrement `<nom-projet>.ton-domaine.com` → IP du serveur

### 3. Template des manifests

#### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: NOM_PROJET
  namespace: NOM_PROJET
spec:
  replicas: 1
  selector:
    matchLabels:
      app: NOM_PROJET
  template:
    metadata:
      labels:
        app: NOM_PROJET
    spec:
      imagePullSecrets:
        - name: registry-credentials
      containers:
        - name: NOM_PROJET
          image: registry.ton-domaine.com/NOM_PROJET:latest
          ports:
            - containerPort: 8080    # adapter au port de l'app
          envFrom:
            - secretRef:
                name: NOM_PROJET-secrets  # optionnel
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
```

#### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: NOM_PROJET
  namespace: NOM_PROJET
spec:
  selector:
    app: NOM_PROJET
  ports:
    - port: 80
      targetPort: 8080    # adapter
```

#### ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: NOM_PROJET
  namespace: NOM_PROJET
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - NOM_PROJET.ton-domaine.com
      secretName: NOM_PROJET-tls
  rules:
    - host: NOM_PROJET.ton-domaine.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: NOM_PROJET
                port:
                  number: 80
```

#### Application ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: NOM_PROJET
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:ton-user/infra.git
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

#### GitHub Actions

```yaml
# .github/workflows/deploy.yaml
name: Build & Deploy

on:
  push:
    branches: [main]

env:
  REGISTRY: registry.ton-domaine.com
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
          sed -i "s|image:.*|image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|" kubernetes/apps/${{ env.IMAGE_NAME }}/deployment.yaml
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "deploy: ${{ env.IMAGE_NAME }} ${{ github.sha }}"
          git push
```

## Résumé — Ajouter un projet en 5 minutes

1. Copier les templates ci-dessus
2. Remplacer `NOM_PROJET` partout
3. Adapter le port et les resources
4. Créer les secrets avec `kubeseal` si besoin
5. Commit + push dans le repo infra
6. ArgoCD détecte et déploie automatiquement
