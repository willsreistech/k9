#!/usr/bin/env bash
# Instala Docker e Kind no servidor Ubuntu 22.04/24.04
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/versions.env"

if [[ "$EUID" -eq 0 ]]; then
  INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
else
  INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
fi
mkdir -p "$INSTALL_DIR"
export PATH="$INSTALL_DIR:$PATH"

case "$(uname -m)" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Arquitetura nao suportada: $(uname -m)" >&2; exit 1 ;;
esac

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
  if command -v kind &>/dev/null && kind version | grep -q "$KIND_VERSION"; then
    log "Kind já instalado: $(kind version)"
    return
  fi
  log "Instalando Kind ${KIND_VERSION}..."
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl -fsSLo "$tmp_dir/kind-linux-${ARCH}" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  curl -fsSLo "$tmp_dir/kind-linux-${ARCH}.sha256sum" \
    "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}.sha256sum"
  (cd "$tmp_dir" && sha256sum --check --status "kind-linux-${ARCH}.sha256sum")
  install -m 0755 "$tmp_dir/kind-linux-${ARCH}" "$INSTALL_DIR/kind"
  rm -rf -- "$tmp_dir"
  log "Kind instalado: $(kind version)"
}

# ── kubectl ──────────────────────────────────────────────────────────────────
install_kubectl() {
  if command -v kubectl &>/dev/null && kubectl version --client -o json 2>/dev/null | grep -q "${KUBECTL_VERSION#v}"; then
    log "kubectl já instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    return
  fi
  log "Instalando kubectl ${KUBECTL_VERSION}..."
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  curl -fsSLo "$tmp_dir/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  curl -fsSLo "$tmp_dir/kubectl.sha256" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"
  printf '%s  %s\n' "$(tr -d '[:space:]' < "$tmp_dir/kubectl.sha256")" "$tmp_dir/kubectl" | sha256sum --check --status
  install -m 0755 "$tmp_dir/kubectl" "$INSTALL_DIR/kubectl"
  rm -rf -- "$tmp_dir"
  log "kubectl instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  if [[ "$EUID" -eq 0 ]]; then
    [[ -r /etc/os-release ]] && source /etc/os-release
    [[ "${ID:-}" == "ubuntu" ]] || { echo "Este instalador suporta apenas Ubuntu." >&2; exit 1; }
    install_docker
    configure_docker_user
  elif ! command -v docker &>/dev/null; then
    echo "Docker nao encontrado. Instale-o previamente no host com privilegios administrativos." >&2
    exit 1
  elif ! docker info &>/dev/null; then
    echo "Docker existe, mas o usuario '$USER' nao consegue acessar o daemon." >&2
    echo "Adicione o usuario ao grupo docker e reinicie o servico do runner." >&2
    exit 1
  fi
  install_kind
  install_kubectl
  log "Binarios instalados em '$INSTALL_DIR'."
  log "✅ Todas as dependências instaladas com sucesso!"
}

main "$@"
