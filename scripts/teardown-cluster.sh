#!/usr/bin/env bash
# Remove o cluster Kind
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lab-k8s}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

main() {
  if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "Cluster '${CLUSTER_NAME}' não encontrado."
    exit 0
  fi

  log "Removendo cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
  rm -f "$HOME/.kube/config-${CLUSTER_NAME}"
  log "✅ Cluster removido."
}

main "$@"
