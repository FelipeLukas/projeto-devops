#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="netmon"

echo "==> Verificando dependências (kind, kubectl, helm)"
for bin in kind kubectl helm; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Falta instalar: $bin"; exit 1; }
done

echo "==> Criando cluster kind (se ainda não existir)"
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  kind create cluster --config "${ROOT_DIR}/kind-config.yaml"
else
  echo "Cluster ${CLUSTER_NAME} já existe, pulando criação."
fi

echo "==> Aplicando namespaces"
kubectl apply -f "${ROOT_DIR}/manifests/00-namespaces/"

echo "==> Aplicando aplicações (frontend/backend)"
kubectl apply -f "${ROOT_DIR}/manifests/20-apps/00-nginx-status-configmap.yaml"
kubectl apply -f "${ROOT_DIR}/manifests/20-apps/10-frontend.yaml"
kubectl apply -f "${ROOT_DIR}/manifests/20-apps/20-backend.yaml"

echo "==> Gerando ConfigMap do simulador de tráfego a partir do script real"
kubectl create configmap traffic-simulator-script \
  --from-file=traffic_simulator.py="${ROOT_DIR}/scripts/traffic_simulator.py" \
  -n traffic-sim --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "${ROOT_DIR}/manifests/20-apps/30-traffic-simulator.yaml"

echo "==> Aplicando stack de observabilidade (Prometheus + Grafana + Loki + Promtail)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  -f "${ROOT_DIR}/manifests/30-monitoring/prometheus-values.yaml"

helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  -f "${ROOT_DIR}/manifests/30-monitoring/loki-stack-values.yaml"

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  -f "${ROOT_DIR}/manifests/30-monitoring/grafana-values.yaml"

echo "==> Aplicando NetworkPolicies (por último, de propósito)"
kubectl apply -f "${ROOT_DIR}/manifests/10-network-policies/"

cat <<'EOM'

==> Setup concluído.

Grafana:    kubectl port-forward -n monitoring svc/grafana 3000:80
Prometheus: kubectl port-forward -n monitoring svc/prometheus-server 9090:80

Usuário do Grafana: admin
Senha:  kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d

Valide o isolamento de rede com:
  ./scripts/validate-network-policies.sh
EOM
