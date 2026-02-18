# Étape 8 — Monitoring (Prometheus + Grafana)

## Prérequis

- k3s fonctionnel (étape 2)
- cert-manager configuré (étape 3)

## Architecture

Le chart `kube-prometheus-stack` est installé via Ansible (rôle `monitoring`), même pattern que les autres composants. Il inclut :

- **Prometheus** — collecte des métriques (rétention 15 jours, PVC 10Gi)
- **Grafana** — dashboards (PVC 2Gi, accès via port-forward)
- **Node Exporter** — métriques système des nodes
- **kube-state-metrics** — métriques des objets Kubernetes
- **Alertmanager** — alertes (PVC 1Gi)

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
| `ruleSelectorNilUsesHelmValues` | `false` (charge les PrometheusRules de tous les namespaces) |
| `ruleNamespaceSelectorNilUsesHelmValues` | `false` |

## Déploiement

```bash
# 1. Ajouter le password Grafana au vault
ansible-vault edit ansible/inventory/group_vars/all/vault.yml
# Ajouter : vault_grafana_password: <mot-de-passe>

# 2. Déployer
cd ansible && make monitoring
```

## Auto-discovery des métriques

Un **ServiceMonitor générique** (`kubernetes/monitoring/service-monitor-generic.yaml`) scrape automatiquement tout Service portant le label `monitoring: "true"`, quel que soit le namespace.

Pour exposer les métriques d'une app, il suffit de :

1. L'app expose `GET /metrics` au format Prometheus
2. Le Service K8s a un port nommé `http`
3. Le Service porte le label `monitoring: "true"`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mon-app
  namespace: mon-app
  labels:
    monitoring: "true"
spec:
  selector:
    app: mon-app
  ports:
    - name: http
      port: 3000
      targetPort: 3000
```

Pas besoin de créer un ServiceMonitor par projet.

## Alertes

Des règles d'alerte sont définies dans `kubernetes/monitoring/prometheus-rules.yaml` :

| Alerte | Condition | Sévérité |
|---|---|---|
| **PodCrashLooping** | > 3 restarts en 10 min | critical |
| **HighErrorRate** | > 5% de 5xx pendant 5 min | warning |
| **PodNotReady** | Pod not ready > 5 min | warning |
| **HighLatency** | p95 > 2s pendant 5 min | warning |

Ces alertes s'appliquent automatiquement à toutes les apps instrumentées.

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

# Accéder à Grafana (port-forward)
make grafana

# Vérifier les targets Prometheus
# Grafana → Connections → Data sources → Prometheus → Test

# Vérifier les alertes
# Grafana → Alerting → Alert rules
```

## Fichiers

- `ansible/roles/monitoring/tasks/main.yml` — rôle Ansible
- `ansible/playbooks/monitoring.yml` — playbook
- `ansible/inventory/group_vars/all/vault.yml` — password Grafana (chiffré)
- `kubernetes/monitoring/service-monitor-generic.yaml` — ServiceMonitor auto-discovery
- `kubernetes/monitoring/prometheus-rules.yaml` — règles d'alerte
- `kubernetes/monitoring/dashboard-app-overview.yaml` — dashboard App Overview
- `kubernetes/monitoring/dashboard-app-logs.yaml` — dashboard App Logs
