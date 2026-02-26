#!/usr/bin/env bash

set -euo pipefail

echo "=========================================="
echo "IoT Part 1 - Host Setup Script"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

if [[ $EUID -eq 0 ]]; then
   print_error "This script must NOT be run as root (it will use sudo when needed)"
   exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    print_error "Cannot detect OS"
    exit 1
fi

print_status "Detected OS: $OS $VER"

print_status "Updating package lists..."
sudo apt-get update -qq

print_status "Installing basic dependencies..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    net-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

print_status "Installing libvirt and QEMU..."
sudo apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    libguestfs-tools \
    libvirt-dev

print_status "Adding $USER to libvirt groups..."
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

print_status "Starting libvirtd service..."
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd

print_status "Installing Vagrant..."
VAGRANT_VERSION="2.4.1"
if ! command -v vagrant &> /dev/null; then
    wget -q https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_amd64.deb
    sudo dpkg -i vagrant_${VAGRANT_VERSION}-1_amd64.deb || sudo apt-get install -f -y
    rm -f vagrant_${VAGRANT_VERSION}-1_amd64.deb
    print_status "Vagrant installed: $(vagrant --version)"
else
    print_warning "Vagrant already installed: $(vagrant --version)"
fi

print_status "Installing vagrant-libvirt plugin..."
if ! vagrant plugin list | grep -q vagrant-libvirt; then
    vagrant plugin install vagrant-libvirt
    print_status "vagrant-libvirt plugin installed"
else
    print_warning "vagrant-libvirt plugin already installed"
fi

print_status "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    print_status "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    print_warning "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

print_status "Ensuring make is installed..."
sudo apt-get install -y make

echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="

check_command() {
    if command -v $1 &> /dev/null; then
        print_status "$1 is installed"
        return 0
    else
        print_error "$1 is NOT installed"
        return 1
    fi
}

ALL_OK=true

check_command vagrant || ALL_OK=false
check_command kubectl || ALL_OK=false
check_command virsh || ALL_OK=false
check_command qemu-system-x86_64 || ALL_OK=false

echo ""
if [ "$ALL_OK" = true ]; then
    print_status "All required tools are installed!"
else
    print_error "Some tools are missing. Please check the output above."
    exit 1
fi

echo ""
print_status "Checking libvirtd status..."
sudo systemctl status libvirtd --no-pager | head -n 3

echo ""
print_warning "IMPORTANT: You need to log out and log back in for group changes to take effect!"
print_warning "After logging back in, you can verify with: groups | grep libvirt"
echo ""
print_status "Setup complete! You can now run 'make' to start the VMs."
echo ""
