#!/usr/bin/env bash
# Instala Docker e Kind no servidor Ubuntu 22.04/24.04
set -euo pipefail

KIND_VERSION="v0.23.0"
KUBECTL_VERSION="v1.30.2"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── Docker ──────────────────────────────────────────────────────────────────
install_docker() {
  if command -v docker &>/dev/null; then
    log "Docker já instalado: $(docker --version)"
    return
  fi
  log "Instalando Docker..."
  apt-get update -qq
  apt-get install -yq ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  log "Docker instalado: $(docker --version)"
}

# ── Adiciona usuário ao grupo docker ────────────────────────────────────────
configure_docker_user() {
  local user="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
  if [[ -n "$user" && "$user" != "root" ]]; then
    usermod -aG docker "$user"
    log "Usuário '$user' adicionado ao grupo docker (relogin necessário)"
  fi
}

# ── Kind ────────────────────────────────────────────────────────────────────
install_kind() {
  if command -v kind &>/dev/null; then
    log "Kind já instalado: $(kind version)"
    return
  fi
  log "Instalando Kind ${KIND_VERSION}..."
  curl -Lo /usr/local/bin/kind \
    "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
  chmod +x /usr/local/bin/kind
  log "Kind instalado: $(kind version)"
}

# ── kubectl ──────────────────────────────────────────────────────────────────
install_kubectl() {
  if command -v kubectl &>/dev/null; then
    log "kubectl já instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    return
  fi
  log "Instalando kubectl ${KUBECTL_VERSION}..."
  curl -Lo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl
  log "kubectl instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Execute como root: sudo $0"
    exit 1
  fi
  install_docker
  configure_docker_user
  install_kind
  install_kubectl
  log "✅ Todas as dependências instaladas com sucesso!"
}

main "$@"
