#!/usr/bin/env bash
# Aplica limites de CPU e memoria aos containers que representam os nos Kind.
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lab-k8s}"
NODE_CPU="${NODE_CPU:-1}"
NODE_MEMORY_GB="${NODE_MEMORY_GB:-2}"

[[ "$CLUSTER_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || {
  echo "Nome de cluster invalido: '$CLUSTER_NAME'." >&2
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

command -v docker &>/dev/null || {
  echo "docker nao encontrado." >&2
  exit 1
}
command -v kind &>/dev/null || {
  echo "kind nao encontrado." >&2
  exit 1
}

mapfile -t nodes < <(kind get nodes --name "$CLUSTER_NAME")
if (( ${#nodes[@]} == 0 )); then
  echo "Nenhum no encontrado para o cluster '$CLUSTER_NAME'." >&2
  exit 1
fi

# Kind nao expoe limites de recursos em sua API v1alpha4. Como cada no e um
# container, o Docker aplica os limites por cgroup no host Linux.
docker update \
  --cpus "$NODE_CPU" \
  --memory "${NODE_MEMORY_GB}g" \
  --memory-swap "${NODE_MEMORY_GB}g" \
  "${nodes[@]}" >/dev/null

for node in "${nodes[@]}"; do
  read -r nano_cpus memory_bytes memory_swap_bytes < <(
    docker inspect --format '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}' "$node"
  )
  expected_nano_cpus=$((NODE_CPU * 1000000000))
  expected_memory_bytes=$((NODE_MEMORY_GB * 1024 * 1024 * 1024))

  if (( nano_cpus != expected_nano_cpus ||
        memory_bytes != expected_memory_bytes ||
        memory_swap_bytes != expected_memory_bytes )); then
    echo "Falha ao validar limites do no '$node'." >&2
    exit 1
  fi

  echo "No '$node': ${NODE_CPU} vCPU, ${NODE_MEMORY_GB} GiB"
done
