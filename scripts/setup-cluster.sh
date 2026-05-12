#!/usr/bin/env bash
# Cria o cluster Kind usando o arquivo de configuração
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lab-k8s}"
CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/../kind/cluster-config.yaml}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

main() {
  log "Verificando dependências..."
  for cmd in docker kind kubectl; do
    command -v "$cmd" &>/dev/null || { echo "❌ '$cmd' não encontrado. Execute scripts/install-deps.sh primeiro."; exit 1; }
  done

  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "⚠️  Cluster '${CLUSTER_NAME}' já existe. Use 'make delete' para recriar."
    exit 0
  fi

  log "Criando cluster Kind '${CLUSTER_NAME}'..."
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "${CONFIG_FILE}" \
    --wait 120s

  log "Configurando kubeconfig..."
  kind get kubeconfig --name "${CLUSTER_NAME}" > "$HOME/.kube/config-${CLUSTER_NAME}"
  export KUBECONFIG="$HOME/.kube/config-${CLUSTER_NAME}"

  log "Verificando nodes..."
  kubectl get nodes -o wide

  log "Verificando pods do sistema..."
  kubectl get pods -A

  log ""
  log "✅ Cluster '${CLUSTER_NAME}' pronto!"
  log ""
  log "Para usar: export KUBECONFIG=\$HOME/.kube/config-${CLUSTER_NAME}"
}

main "$@"
