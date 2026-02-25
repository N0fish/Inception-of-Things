#!/usr/bin/env bash


set -euo pipefail


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
section() {
    echo ""
    echo -e "${BLUE}  $*${NC}"
    echo ""
}

have() { command -v "$1" &>/dev/null; }

if [[ $EUID -eq 0 ]]; then
    error "Do not run as root — this script calls sudo internally."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS (/etc/os-release not found)."
    exit 1
fi

source /etc/os-release
info "Detected OS: ${PRETTY_NAME:-$ID $VERSION_ID}"
echo ""

NEED_RELOGIN=0

section "SYSTEM UPDATE & COMMON TOOLS"

info "Updating package lists..."
sudo apt-get update -qq

info "Installing common tools..."
sudo apt-get install -y \
    curl wget git build-essential net-tools \
    ca-certificates gnupg lsb-release software-properties-common \
    acl

section "PART 1 & 2 — libvirt / QEMU / Vagrant  (VM-based parts)"

info "Installing libvirt and QEMU/KVM..."
sudo apt-get install -y \
    qemu-kvm libvirt-daemon-system libvirt-clients \
    bridge-utils virt-manager libguestfs-tools libvirt-dev

info "Starting and enabling libvirtd..."
sudo systemctl enable --now libvirtd

info "Adding $USER to libvirt/kvm groups..."
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm     "$USER"
NEED_RELOGIN=1

info "Installing Vagrant (via HashiCorp apt repo)..."
if ! have vagrant; then
    wget -qO- https://apt.releases.hashicorp.com/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y vagrant
    info "Vagrant installed: $(vagrant --version)"
else
    warn "Vagrant already installed: $(vagrant --version)"
fi

info "Installing vagrant-libvirt plugin..."
if ! vagrant plugin list 2>/dev/null | grep -q vagrant-libvirt; then
    sudo apt-get install -y ruby-libvirt
    vagrant plugin install vagrant-libvirt
    info "vagrant-libvirt plugin installed."
else
    warn "vagrant-libvirt plugin already installed."
fi

section "PART 3 — Docker / K3d  (container-based cluster)"

info "Installing Docker..."
if ! have docker; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    NEED_RELOGIN=1
    info "Docker installed: $(docker --version)"
else
    warn "Docker already installed: $(docker --version)"
fi

info "Installing K3d..."
if ! have k3d; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    info "K3d installed: $(k3d version | head -1)"
else
    warn "K3d already installed: $(k3d version | head -1)"
fi

section "BONUS — Helm  (GitLab Helm chart)"

info "Installing Helm..."
if ! have helm; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    info "Helm installed: $(helm version --short)"
else
    warn "Helm already installed: $(helm version --short)"
fi

section "ALL PARTS — kubectl / make"

info "Installing kubectl..."
if ! have kubectl; then
    KUBECTL_VER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    info "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    warn "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

info "Installing make..."
sudo apt-get install -y make

section "VERIFICATION"

check_cmd() {
    if have "$1"; then
        info "$1  ✓"
    else
        error "$1  ✗  (not found — check output above)"
        return 1
    fi
}

ALL_OK=true
check_cmd vagrant  || ALL_OK=false
check_cmd virsh    || ALL_OK=false
check_cmd docker   || ALL_OK=false
check_cmd k3d      || ALL_OK=false
check_cmd kubectl  || ALL_OK=false
check_cmd helm     || ALL_OK=false
check_cmd make     || ALL_OK=false

echo ""
if [[ "$ALL_OK" == true ]]; then
    info "All required tools are installed!"
else
    error "Some tools are missing — review the output above."
    exit 1
fi

echo ""
if [[ "$NEED_RELOGIN" -eq 1 ]]; then
    warn "IMPORTANT: Log out and log back in for group changes to take effect!"
    warn "(libvirt, kvm, and docker groups require a new login session)"
    echo ""
fi

info "You can now run each part:"
echo ""

