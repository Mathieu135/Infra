# Étape 6 — Sealed Secrets

## Prérequis

- k3s fonctionnel (étape 2)

## Pourquoi Sealed Secrets

- Les `Secret` Kubernetes sont en base64, pas chiffrés → pas safe dans Git
- Sealed Secrets chiffre les secrets avec une clé publique du cluster
- Seul le controller sur le cluster peut déchiffrer
- On peut commiter les `SealedSecret` dans Git en toute sécurité

## Installation

### Controller sur le cluster

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system
```

### CLI sur ton Mac

```bash
brew install kubeseal
```

## Utilisation

### 1. Créer un Secret classique (ne pas commiter celui-ci)

```bash
kubectl create secret generic mon-secret \
  --namespace mon-app \
  --from-literal=DATABASE_URL=postgres://user:pass@host/db \
  --dry-run=client -o yaml > /tmp/mon-secret.yaml
```

### 2. Le chiffrer avec kubeseal

```bash
kubeseal --format yaml < /tmp/mon-secret.yaml > kubernetes/apps/mon-app/sealed-secret.yaml

# Supprimer le secret en clair
rm /tmp/mon-secret.yaml
```

### 3. Commiter le SealedSecret

```yaml
# kubernetes/apps/mon-app/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: mon-secret
  namespace: mon-app
spec:
  encryptedData:
    DATABASE_URL: AgBy8h... # chiffré, safe dans Git
```

### 4. ArgoCD applique le SealedSecret → le controller le déchiffre en Secret

## Workflow résumé

```
1. kubectl create secret ... --dry-run -o yaml > /tmp/secret.yaml
2. kubeseal < /tmp/secret.yaml > kubernetes/apps/mon-app/sealed-secret.yaml
3. rm /tmp/secret.yaml
4. git add + commit + push
5. ArgoCD sync → controller déchiffre → Secret disponible pour les pods
```

## Backup de la clé de chiffrement

La clé privée du controller est dans le cluster. Si tu perds le cluster, tu perds la capacité de déchiffrer.

```bash
# Backup la clé
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml

# Stocker ce fichier en SÉCURITÉ (pas dans Git !)
# Exemple : gestionnaire de mots de passe, coffre-fort
```

## Vérification

```bash
# Vérifier que le controller tourne
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Vérifier qu'un SealedSecret se déchiffre
kubectl get secret mon-secret -n mon-app
```

## Fichiers à créer

- `kubernetes/apps/<projet>/sealed-secret.yaml` — un par projet
