#!/usr/bin/env bash
set -euo pipefail

# Installs: docker, kubectl, k3d, helm, argocd CLI
# Target: Ubuntu/Debian-like systems (typical IOT host VM)

need_cmd() { command -v "$1" >/dev/null 2>&1; }

log() { echo "[install-tools] $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  log "Please run as root: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log "Updating apt..."
apt-get update -qq

log "Installing base packages..."
apt-get install -y curl ca-certificates gnupg lsb-release apt-transport-https jq

# -------------------------
# Docker
# -------------------------
if ! need_cmd docker; then
  log "Installing docker (docker.io from apt)..."
  apt-get install -y docker.io
  systemctl enable --now docker
else
  log "Docker already installed."
fi

# Add invoking user to docker group (best-effort)
INVOKER_USER="${SUDO_USER:-}"
if [[ -n "${INVOKER_USER}" ]]; then
  if getent group docker >/dev/null 2>&1; then
    usermod -aG docker "${INVOKER_USER}" || true
    log "Added ${INVOKER_USER} to docker group (log out/in to apply)."
  fi
fi

# -------------------------
# kubectl
# -------------------------
if ! need_cmd kubectl; then
  log "Installing kubectl..."
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl
else
  log "kubectl already installed."
fi

# -------------------------
# k3d
# -------------------------
if ! need_cmd k3d; then
  log "Installing k3d..."
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  log "k3d already installed."
fi

# -------------------------
# helm
# -------------------------
if ! need_cmd helm; then
  log "Installing helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  log "helm already installed."
fi

# -------------------------
# argocd CLI
# -------------------------
if ! need_cmd argocd; then
  log "Installing argocd CLI..."
  # Latest stable Linux amd64 binary
  curl -fsSLo /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /usr/local/bin/argocd
else
  log "argocd CLI already installed."
fi

log "Done."
log "NOTE: If docker group was updated, log out/in (or 'newgrp docker') to use docker without sudo."
