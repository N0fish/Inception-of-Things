#!/bin/bash

# Host machine setup script for Ubuntu 22.04 LTS
# Installs all required software for the IoT project

set -e

echo "======================================"
echo "IoT Project - Host Setup"
echo "Ubuntu 22.04 LTS"
echo "======================================"
echo ""

# Check if running on Ubuntu
if [ ! -f /etc/lsb-release ]; then
    echo "ERROR: This script is for Ubuntu systems"
    exit 1
fi

. /etc/lsb-release
if [ "$DISTRIB_ID" != "Ubuntu" ]; then
    echo "ERROR: This script is for Ubuntu systems"
    exit 1
fi

echo "Detected: $DISTRIB_DESCRIPTION"
echo ""

# Update package list
echo "==> Updating package list..."
sudo apt-get update

# Install libvirt and QEMU/KVM
echo "==> Installing libvirt and QEMU/KVM..."
if ! command -v virsh &> /dev/null; then
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
    sudo systemctl enable libvirtd
    sudo systemctl start libvirtd

    # Add current user to libvirt groups
    sudo usermod -aG libvirt $USER
    sudo usermod -aG kvm $USER
    echo "libvirt installed. You need to log out and log back in for group permissions."
    NEED_RELOGIN=1
else
    echo "libvirt already installed"
fi

# Install Vagrant
echo "==> Installing Vagrant..."
if ! command -v vagrant &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update
    sudo apt-get install -y vagrant
else
    echo "Vagrant already installed"
fi

# Install vagrant-libvirt plugin
echo "==> Installing vagrant-libvirt plugin..."
if ! vagrant plugin list | grep -q vagrant-libvirt; then
    sudo apt-get install -y ruby-libvirt libvirt-dev
    vagrant plugin install vagrant-libvirt
else
    echo "vagrant-libvirt plugin already installed"
fi

# Install Make
echo "==> Installing Make..."
if ! command -v make &> /dev/null; then
    sudo apt-get install -y build-essential
else
    echo "Make already installed"
fi

# Install Docker for Part 3
echo "==> Installing Docker..."
if ! command -v docker &> /dev/null; then
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER
    echo "Docker installed. You need to log out and log back in for group permissions."
    NEED_RELOGIN=1
else
    echo "Docker already installed"
fi

# Install kubectl
echo "==> Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "kubectl already installed"
fi

# Install K3d
echo "==> Installing K3d..."
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "K3d already installed"
fi

# Install curl (if not present)
echo "==> Installing curl..."
if ! command -v curl &> /dev/null; then
    sudo apt-get install -y curl
else
    echo "curl already installed"
fi

# Install Helm (required for bonus GitLab installation)
echo "==> Installing Helm..."
if ! command -v helm &> /dev/null; then
    sudo snap install helm --classic
else
    echo "Helm already installed"
fi

echo ""
echo "======================================"
echo "Installation complete!"
echo "======================================"
echo ""
echo "Installed software:"
echo "  libvirt: $(virsh --version)"
echo "  Vagrant: $(vagrant --version)"
echo "  vagrant-libvirt: $(vagrant plugin list | grep vagrant-libvirt)"
echo "  Make: $(make --version | head -1)"
echo "  Docker: $(docker --version)"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "  K3d: $(k3d version | head -1)"
echo ""

if [ "$NEED_RELOGIN" = "1" ]; then
    echo "IMPORTANT: You must log out and log back in before running the project"
    echo "           (libvirt, KVM, and Docker group permissions require re-login)"
    echo ""
fi

echo "You can now run:"
echo "  Part 1: cd p1 && make up"
echo "  Part 2: cd p2 && make up"
echo "  Part 3: cd p3 && make all-in-one (after re-login if Docker was installed)"
