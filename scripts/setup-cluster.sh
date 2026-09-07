#!/usr/bin/env bash
# Cria o cluster Kind usando o arquivo de configuração
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lab-k8s}"
CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/../kind/cluster-config.yaml}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_ROOT="${DATA_ROOT:-$HOME/.local/share/kind}"
NODE_CPU="${NODE_CPU:-1}"
NODE_MEMORY_GB="${NODE_MEMORY_GB:-2}"
RENDERED_CONFIG=""

log() { echo "[$(date '+%H:%M:%S')] $*"; }
cleanup() { [[ -z "$RENDERED_CONFIG" ]] || rm -f -- "$RENDERED_CONFIG"; }
trap cleanup EXIT

main() {
  [[ "$CLUSTER_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || {
    echo "Nome de cluster invalido: '$CLUSTER_NAME'. Use letras minusculas, numeros e hifens." >&2
    exit 2
  }
  [[ "$DATA_ROOT" == /* && "$DATA_ROOT" =~ ^[a-zA-Z0-9._/-]+$ ]] || {
    echo "DATA_ROOT deve ser um caminho absoluto sem espacos: '$DATA_ROOT'." >&2
    exit 2
  }
  [[ "$NODE_CPU" =~ ^(1|2|4)$ ]] || {
    echo "NODE_CPU invalido: '$NODE_CPU'. Use 1, 2 ou 4." >&2
    exit 2
  }
  [[ "$NODE_MEMORY_GB" =~ ^(1|2|4|8)$ ]] || {
    echo "NODE_MEMORY_GB invalido: '$NODE_MEMORY_GB'. Use 1, 2, 4 ou 8." >&2
    exit 2
  }

  local data_dir="$DATA_ROOT/$CLUSTER_NAME"
  RENDERED_CONFIG="$(mktemp)"

  log "Verificando dependências..."
  for cmd in docker kind kubectl; do
    command -v "$cmd" &>/dev/null || { echo "❌ '$cmd' não encontrado. Execute scripts/install-deps.sh primeiro."; exit 1; }
  done

  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "⚠️  Cluster '${CLUSTER_NAME}' já existe. Use 'make delete' para recriar."
    exit 0
  fi

  mkdir -p "$data_dir" "$HOME/.kube"
  chmod 0700 "$data_dir"
  CONFIG_FILE="$CONFIG_FILE" NODE_CPU="$NODE_CPU" NODE_MEMORY_GB="$NODE_MEMORY_GB" \
    bash "$PROJECT_ROOT/scripts/render-kind-config.sh" > "$RENDERED_CONFIG"

  log "Criando cluster Kind '${CLUSTER_NAME}'..."
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "$RENDERED_CONFIG" \
    --wait 120s

  log "Aplicando ${NODE_CPU} vCPU e ${NODE_MEMORY_GB} GiB de memoria por no..."
  NODE_CPU="$NODE_CPU" NODE_MEMORY_GB="$NODE_MEMORY_GB" \
    bash "$PROJECT_ROOT/scripts/configure-node-resources.sh"

  log "Configurando kubeconfig..."
  kind get kubeconfig --name "${CLUSTER_NAME}" > "$HOME/.kube/config-${CLUSTER_NAME}"
  export KUBECONFIG="$HOME/.kube/config-${CLUSTER_NAME}"

  log "Verificando nodes..."
  kubectl get nodes -o wide

  log "Verificando pods do sistema..."
  kubectl get pods -A

  log "Aguardando todos os nodes ficarem Ready..."
  kubectl wait --for=condition=Ready nodes --all --timeout=120s

  log "Aplicando baseline de seguranca e recursos..."
  kubectl apply -f "$PROJECT_ROOT/manifests/platform-baseline.yaml"

  log ""
  log "✅ Cluster '${CLUSTER_NAME}' pronto!"
  log ""
  log "Para usar: export KUBECONFIG=\$HOME/.kube/config-${CLUSTER_NAME}"
}

main "$@"
