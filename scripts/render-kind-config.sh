#!/usr/bin/env bash
# Renderiza o template Kind no stdout sem criar recursos.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/kind/cluster-config.yaml}"
CLUSTER_NAME="${CLUSTER_NAME:-lab-k8s}"
DATA_ROOT="${DATA_ROOT:-$HOME/.local/share/kind}"

[[ "$CLUSTER_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || {
  echo "Nome de cluster invalido: '$CLUSTER_NAME'." >&2
  exit 2
}
[[ "$DATA_ROOT" == /* && "$DATA_ROOT" =~ ^[a-zA-Z0-9._/-]+$ ]] || {
  echo "DATA_ROOT deve ser um caminho absoluto sem espacos: '$DATA_ROOT'." >&2
  exit 2
}

# shellcheck disable=SC1091
source "$PROJECT_ROOT/versions.env"

sed -e "s|__DATA_DIR__|${DATA_ROOT}/${CLUSTER_NAME}|g" \
    -e "s|__KIND_NODE_IMAGE__|${KIND_NODE_IMAGE}|g" \
    "$CONFIG_FILE"
