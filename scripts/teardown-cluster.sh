#!/usr/bin/env bash
# Remove o cluster Kind
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lab-k8s}"
DATA_ROOT="${DATA_ROOT:-$HOME/.local/share/kind}"
DELETE_DATA="${DELETE_DATA:-false}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

main() {
  [[ "$CLUSTER_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || {
    echo "Nome de cluster invalido: '$CLUSTER_NAME'." >&2
    exit 2
  }
  [[ "$DATA_ROOT" == /* && "$DATA_ROOT" =~ ^[a-zA-Z0-9._/-]+$ ]] || {
    echo "DATA_ROOT deve ser um caminho absoluto sem espacos: '$DATA_ROOT'." >&2
    exit 2
  }
  if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "Cluster '${CLUSTER_NAME}' não encontrado."
    exit 0
  fi

  log "Removendo cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
  rm -f "$HOME/.kube/config-${CLUSTER_NAME}"
  if [[ "$DELETE_DATA" == "true" ]]; then
    local data_dir="$DATA_ROOT/$CLUSTER_NAME"
    [[ "$data_dir" == "$DATA_ROOT/"* && "$data_dir" != "$DATA_ROOT/" ]] || {
      echo "Diretorio de dados inseguro: '$data_dir'." >&2
      exit 2
    }
    rm -rf -- "$data_dir"
    log "Dados persistentes removidos de '$data_dir'."
  fi
  log "✅ Cluster removido."
}

main "$@"
