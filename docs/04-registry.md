# Étape 4 — Docker Registry self-hosted

## Prérequis

- k3s fonctionnel (étape 2)
- cert-manager configuré (étape 3)
- DNS configuré : `registry.ton-domaine.com` → IP du serveur

## Pourquoi self-hosted

- Gratuit, pas de limite de stockage/bande passante
- Tes images restent chez toi
- Pas besoin de compte Docker Hub ou ghcr.io payant

## Installation via Helm

```bash
helm repo add twuni https://helm.twun.io
helm repo update

helm install registry twuni/docker-registry \
  --namespace registry \
  --create-namespace \
  --set persistence.enabled=true \
  --set persistence.size=20Gi
```

## Ingress pour exposer le registry

```yaml
# kubernetes/registry/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: registry
  namespace: registry
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    # Augmenter la taille max pour les layers Docker
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  tls:
    - hosts:
        - registry.ton-domaine.com
      secretName: registry-tls
  rules:
    - host: registry.ton-domaine.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: registry-docker-registry
                port:
                  number: 5000
```

## Authentification

Créer un htpasswd secret pour protéger le registry :

```bash
# Générer le fichier htpasswd
htpasswd -Bbn monuser monpassword > auth/htpasswd

# Créer le secret Kubernetes
kubectl create secret generic registry-auth \
  --namespace registry \
  --from-file=htpasswd=auth/htpasswd
```

Puis ajouter dans les values Helm :

```yaml
secrets:
  htpasswd: ""  # sera lu depuis le secret
```

## Configurer k3s pour pull depuis ce registry

Créer le fichier sur le serveur :

```yaml
# /etc/rancher/k3s/registries.yaml
mirrors:
  registry.ton-domaine.com:
    endpoint:
      - "https://registry.ton-domaine.com"
configs:
  registry.ton-domaine.com:
    auth:
      username: monuser
      password: monpassword
```

Redémarrer k3s :

```bash
sudo systemctl restart k3s
```

## Configurer Docker local pour push

```bash
# Se connecter au registry depuis ton Mac
docker login registry.ton-domaine.com

# Tagger et push une image
docker tag mon-app:latest registry.ton-domaine.com/mon-app:latest
docker push registry.ton-domaine.com/mon-app:latest
```

## Vérification

```bash
# Vérifier que le registry tourne
kubectl get pods -n registry

# Tester le push/pull
docker pull alpine
docker tag alpine registry.ton-domaine.com/test:latest
docker push registry.ton-domaine.com/test:latest

# Lister les images
curl -u monuser:monpassword https://registry.ton-domaine.com/v2/_catalog
```

## Fichiers à créer

- `kubernetes/registry/ingress.yaml`
- `kubernetes/registry/values.yaml` (values Helm custom)
