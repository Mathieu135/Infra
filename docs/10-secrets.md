# Étape 10 — Gestion des secrets (SOPS + age)

## Principe

Les secrets applicatifs sont chiffrés dans Git avec [SOPS](https://github.com/getsops/sops) et [age](https://github.com/FiloSottile/age). ArgoCD les déchiffre au moment du sync via [KSOPS](https://github.com/viaduct-ai/kustomize-sops) (plugin Kustomize exec).

Avantages par rapport à Sealed Secrets :
- Secrets versionnés dans Git (historique, diff, review)
- Édition directe avec `sops` (pas de re-seal)
- Pas de dépendance à un controller côté cluster
- Rotation simplifiée

## Prérequis

```bash
brew install sops age
```

La clé publique age est configurée dans `.sops.yaml` à la racine du repo.

## Workflow

### Créer un secret pour une nouvelle app

```bash
make secret-create APP=mon-app
# Ouvre l'éditeur avec un template — remplir les valeurs
```

Cela crée :
- `kubernetes/apps/mon-app/secrets.enc.yaml` — le Secret chiffré
- `kubernetes/apps/mon-app/ksops-generator.yaml` — le générateur KSOPS

Ajouter le générateur dans `kustomization.yaml` :

```yaml
generators:
  - ksops-generator.yaml
```

### Éditer un secret existant

```bash
make secret-edit APP=portfolio
```

Ouvre le fichier déchiffré dans `$EDITOR`. Les modifications sont re-chiffrées automatiquement à la sauvegarde.

### Voir un secret en clair

```bash
make secret-view APP=portfolio
```

### Ajouter une clé à un secret existant

```bash
make secret-edit APP=portfolio
# Ajouter la nouvelle clé sous stringData:, sauvegarder
```

## Structure des fichiers

```
kubernetes/apps/mon-app/
├── kustomization.yaml          # generators: [ksops-generator.yaml]
├── ksops-generator.yaml        # pointe vers secrets.enc.yaml
├── secrets.enc.yaml            # Secret K8s chiffré SOPS
├── deployment.yaml
├── service.yaml
└── ingress.yaml
```

## Comment ça fonctionne

1. `secrets.enc.yaml` est un Secret K8s standard dont les valeurs sont chiffrées par SOPS
2. `ksops-generator.yaml` est un générateur Kustomize qui appelle KSOPS
3. ArgoCD utilise Kustomize avec `--enable-exec` pour exécuter KSOPS
4. KSOPS déchiffre le fichier avec la clé age montée dans le repo-server
5. Le Secret en clair est appliqué dans le cluster

## Rotation de la clé age

1. Générer une nouvelle clé : `age-keygen -o /tmp/new-key.txt`
2. Mettre à jour `.sops.yaml` avec la nouvelle clé publique
3. Re-chiffrer tous les secrets : `find kubernetes -name "*.enc.yaml" -exec sops updatekeys {} \;`
4. Mettre à jour le Secret K8s `sops-age-key` dans le namespace `argocd`
5. Redémarrer le repo-server ArgoCD

## Dépannage

### ArgoCD ne déchiffre pas le secret

1. Vérifier que le Secret `sops-age-key` existe : `kubectl get secret sops-age-key -n argocd`
2. Vérifier les logs du repo-server : `kubectl logs -n argocd -l app.kubernetes.io/component=repo-server`
3. Vérifier que KSOPS est installé : le initContainer `install-ksops` doit être en état Completed

### Erreur "age: no identity matched any of the recipients"

La clé privée dans le cluster ne correspond pas à la clé publique dans `.sops.yaml`. Recréer le Secret avec la bonne clé.
