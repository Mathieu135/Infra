# Étape 8 — Monitoring (Prometheus + Grafana)

## Prérequis

- k3s fonctionnel (étape 2)
- cert-manager configuré (étape 3)
- DNS : `grafana.matltz.dev` → `91.134.142.175` (A record, DNS only sur Cloudflare)

## Architecture

Le chart `kube-prometheus-stack` est installé via Ansible (rôle `monitoring`), même pattern que les autres composants. Il inclut :

- **Prometheus** — collecte des métriques (rétention 15 jours, PVC 10Gi)
- **Grafana** — dashboards (PVC 2Gi, exposé sur `grafana.matltz.dev`)
- **Node Exporter** — métriques système des nodes
- **kube-state-metrics** — métriques des objets Kubernetes
- Alertmanager désactivé (pas configuré pour l'instant)

## Configuration

Les values sont passées en `--set` dans le rôle Ansible (`ansible/roles/monitoring/tasks/main.yml`) :

| Paramètre | Valeur |
|---|---|
| `grafana.adminPassword` | Via Ansible Vault (`vault_grafana_password`) |
| `prometheus.prometheusSpec.retention` | `15d` |
| `prometheus.prometheusSpec.storageSpec` | PVC 10Gi |
| `grafana.persistence` | Activée, 2Gi |
| `serviceMonitorSelectorNilUsesHelmValues` | `false` (scrape tous les namespaces) |
| `podMonitorSelectorNilUsesHelmValues` | `false` |
| `alertmanager.enabled` | `false` |

## Déploiement

```bash
# 1. Ajouter le password Grafana au vault
ansible-vault edit ansible/inventory/group_vars/all/vault.yml
# Ajouter : vault_grafana_password: <mot-de-passe>

# 2. Déployer
cd ansible && make monitoring
```

## Exposer les métriques de tes apps

Ajouter un `ServiceMonitor` pour chaque app qui expose des métriques Prometheus :

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mon-app
  namespace: mon-app
spec:
  selector:
    matchLabels:
      app: mon-app
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

## Dashboards

Le chart installe automatiquement des dashboards pour :

- Cluster health (nodes, pods, resources)
- Kubernetes API server
- Workloads (deployments, statefulsets)
- Node Exporter (CPU, RAM, disk, network)
- Persistent volumes

Pour ajouter un dashboard custom, créer un ConfigMap avec le label `grafana_dashboard: "1"` :

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mon-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  mon-dashboard.json: |
    { ... JSON du dashboard ... }
```

## Vérification

```bash
# Vérifier les pods
kubectl get pods -n monitoring

# Accéder à Grafana
# https://grafana.matltz.dev (admin / <password du vault>)

# Vérifier les targets Prometheus
# Grafana → Connections → Data sources → Prometheus → Test
```

## Fichiers

- `ansible/roles/monitoring/tasks/main.yml` — rôle Ansible
- `ansible/playbooks/monitoring.yml` — playbook
- `ansible/inventory/group_vars/all/vault.yml` — password Grafana (chiffré)
