# Étape 8 — Monitoring (Prometheus + Grafana)

## Prérequis

- k3s fonctionnel (étape 2)
- cert-manager configuré (étape 3)
- DNS configuré : `grafana.ton-domaine.com` → IP du serveur

## Installation via Helm

Le chart `kube-prometheus-stack` inclut tout : Prometheus, Grafana, Alertmanager, et les dashboards de base.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values kubernetes/monitoring/values.yaml
```

## Values personnalisées

```yaml
# kubernetes/monitoring/values.yaml
grafana:
  adminPassword: "a-changer-via-sealed-secret"

  ingress:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - grafana.ton-domaine.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.ton-domaine.com

  persistence:
    enabled: true
    size: 5Gi

prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi

    # Scraper tous les ServiceMonitors dans tous les namespaces
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

alertmanager:
  enabled: true
  # Configurer les notifications (email, Slack, etc.) si besoin
```

## Exposer les métriques de tes apps

Ajouter un `ServiceMonitor` pour chaque app qui expose des métriques Prometheus :

```yaml
# kubernetes/apps/mon-app/service-monitor.yaml
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

## Dashboards inclus par défaut

Le chart installe automatiquement des dashboards pour :

- Cluster health (nodes, pods, resources)
- Kubernetes API server
- Workloads (deployments, statefulsets)
- Networking
- Persistent volumes

## Ajouter des dashboards custom

Via ConfigMap provisionné :

```yaml
# kubernetes/monitoring/dashboards/mon-dashboard.yaml
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

Ou importer depuis Grafana.com par ID dans les values :

```yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: default
          folder: ""
          type: file
          options:
            path: /var/lib/grafana/dashboards/default
  dashboards:
    default:
      node-exporter:
        gnetId: 1860
        revision: 36
        datasource: Prometheus
```

## Vérification

```bash
# Vérifier les pods monitoring
kubectl get pods -n monitoring

# Accéder à Grafana
# https://grafana.ton-domaine.com
# User : admin / Password : celui configuré dans les values

# Vérifier les targets Prometheus
# Grafana → Explore → Prometheus → up
```

## Fichiers à créer

- `kubernetes/monitoring/values.yaml`
- `kubernetes/monitoring/dashboards/` — dashboards custom (optionnel)
