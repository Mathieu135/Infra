# Étape 11 — NetworkPolicies

## Principe

Chaque namespace a des NetworkPolicies qui restreignent le trafic réseau. Par défaut tout est bloqué (deny), puis des règles explicites autorisent les flux nécessaires.

## Approche par type de namespace

### Namespaces applicatifs (portfolio, registry)

**Deny ingress + egress** — isolation stricte. Seuls les flux explicitement autorisés passent.

Policies types :

| Policy | Rôle |
|--------|------|
| `default-deny` | Bloque tout trafic (ingress + egress) |
| `allow-dns` | Autorise DNS vers kube-system:53 |
| `allow-ingress-to-*` | Autorise le trafic entrant depuis ingress-nginx ou intra-namespace |
| `allow-*-to-*` | Autorise l'egress vers des pods spécifiques |

### Namespaces infra (monitoring, argocd)

**Deny ingress seulement** — egress non restreint.

Raison : sur k3s, le ClusterIP du K8s API (`10.43.0.1`) ne peut pas être ciblé par NetworkPolicy. L'IP est virtuelle (iptables DNAT) et le comportement est indéfini selon la doc Kubernetes. Restreindre l'egress casserait l'accès au K8s API pour le controller ArgoCD, l'operator Prometheus, kube-state-metrics, etc.

Policies types :

| Policy | Rôle |
|--------|------|
| `default-deny-ingress` | Bloque tout trafic entrant |
| `allow-intra-namespace` | Autorise l'ingress depuis le même namespace |

## Flux réseau par namespace

### portfolio

```
Internet → ingress-nginx → frontend:80 → backend:3001
                                          ↑ Prometheus scrape (monitoring ns)
```

5 policies : default-deny, allow-dns, allow-ingress-to-frontend, allow-ingress-to-backend, allow-frontend-to-backend.

### registry

```
Internet → ingress-nginx → registry-ui:80 → docker-registry:5000
                                              ↑ cleanup cronjob
```

5 policies : default-deny, allow-dns, allow-ingress-to-ui, allow-ingress-to-registry, allow-egress-to-registry.

### monitoring

Egress libre (Prometheus scrape cross-namespace, operator/kube-state-metrics → K8s API).

2 policies : default-deny-ingress, allow-intra-namespace.

### argocd

Egress libre (controller → K8s API, repo-server → GitHub SSH/HTTPS).

2 policies : default-deny-ingress, allow-intra-namespace.

## Ajouter des NetworkPolicies pour un nouveau projet

Copier le pattern de portfolio et adapter :

1. Créer `kubernetes/apps/<nom>/network-policy.yaml`
2. Ajouter `network-policy.yaml` dans `kustomization.yaml`
3. Adapter les `podSelector` (labels de vos pods) et les ports

Template minimal pour une app avec un seul pod :

```yaml
# Default deny
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: <nom>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# DNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <nom>
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
---
# Ingress depuis ingress-nginx
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress
  namespace: <nom>
spec:
  podSelector:
    matchLabels:
      app: <nom>
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: <port>
---
# Prometheus scrape (si monitoring: "true" sur le Service)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: <nom>
spec:
  podSelector:
    matchLabels:
      app: <nom>
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: <port>
```

## Limites sur k3s

- `ipBlock` ne fonctionne pas avec les ClusterIP (IP virtuelles, DNAT avant évaluation)
- `kubectl port-forward` bypass les NetworkPolicies (tunnel kubelet)
- Les pods sur le host network (ex: node-exporter) ne sont pas affectés par les NetworkPolicies

## Fichiers

- `kubernetes/apps/portfolio/network-policy.yaml`
- `kubernetes/registry/network-policy.yaml`
- `kubernetes/monitoring/network-policy.yaml`
- `kubernetes/argocd-policies/network-policy.yaml`
