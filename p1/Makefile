# Makefile for Inception-of-Things Part 1
# Usage: make [target]

.PHONY: help setup up start server worker ssh-server ssh-worker status check destroy clean re test \
		fix-permissions acl acl-hardcoded use-rsync use-nfs reload provision halt logs-server logs-worker

SHELL := /bin/bash

# Configuration
LOGIN := urosby
SERVER_NAME := $(LOGIN)S
WORKER_NAME := $(LOGIN)SW
SERVER_IP := 192.168.56.110
WORKER_IP := 192.168.56.111

# Project path + qemu user autodetect (libvirt)
PROJECT_DIR := $(shell pwd)

# Prefer a stable default for libvirt instead of relying on a currently-running qemu process
QEMU_USER ?= $(shell id -u libvirt-qemu >/dev/null 2>&1 && echo libvirt-qemu || echo qemu)

# Colors for output (used with printf)
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@printf "$(GREEN)Inception-of-Things Part 1 - Makefile$(NC)\n\n"
	@printf "Available targets:\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@printf "\n"

setup: ## Install all required dependencies on the host
	@printf "$(GREEN)[+] Installing dependencies...$(NC)\n"
	@chmod +x setup-host.sh
	@./setup-host.sh

acl: ## Fix libvirt 9p permission issues (ACLs for qemu user on this project dir)
	@set -e; \
	printf "$(GREEN)[+] Using qemu user: $(QEMU_USER)$(NC)\n"; \
	printf "$(GREEN)[+] Granting ACLs for 9p share path: $(PROJECT_DIR)$(NC)\n"; \
	\
	# Ensure confs exists on host (so defaults apply there too)
	mkdir -p "$(PROJECT_DIR)/confs"; \
	\
	# Parents must be traversable (--x) for qemu to reach the project dir
	p="$(PROJECT_DIR)"; \
	parents=(); \
	while [ "$$p" != "/" ] && [ -n "$$p" ]; do \
		parents+=("$$p"); \
		p="$$(dirname "$$p")"; \
	done; \
	for d in "$${parents[@]}"; do \
		sudo setfacl -m u:$(QEMU_USER):--x "$$d" || true; \
	done; \
	\
	# Project dir: qemu needs RWX to allow guest create/write
	sudo setfacl -m u:$(QEMU_USER):rwx  "$(PROJECT_DIR)"; \
	sudo setfacl -d -m u:$(QEMU_USER):rwx "$(PROJECT_DIR)"; \
	\
	# Everything under confs must be writable too (and default for new files)
	sudo setfacl -R -m u:$(QEMU_USER):rwx "$(PROJECT_DIR)/confs"; \
	sudo setfacl -R -d -m u:$(QEMU_USER):rwx "$(PROJECT_DIR)/confs"; \
	\
	printf "$(GREEN)[+] ACLs applied. Now run: make clean && make up$(NC)\n"

acl-hardcoded: ## Run the exact hardcoded ACL commands for /home/urosby/Documents/IOT/p1
	@printf "$(GREEN)[+] Showing qemu processes (if any)$(NC)\n"
	@ps -eo user,comm | grep -E 'qemu-system|qemu-kvm' | head || true
	@printf "$(GREEN)[+] Applying hardcoded ACL rules for libvirt-qemu$(NC)\n"
	sudo setfacl -m u:libvirt-qemu:--x /home/urosby
	sudo setfacl -m u:libvirt-qemu:--x /home/urosby/Documents
	sudo setfacl -m u:libvirt-qemu:--x /home/urosby/Documents/IOT
	sudo setfacl -m u:libvirt-qemu:rwx /home/urosby/Documents/IOT/p1
	sudo setfacl -d -m u:libvirt-qemu:rwx /home/urosby/Documents/IOT/p1
	sudo setfacl -R -m u:libvirt-qemu:rwx /home/urosby/Documents/IOT/p1/confs
	sudo setfacl -R -d -m u:libvirt-qemu:rwx /home/urosby/Documents/IOT/p1/confs
	@printf "$(GREEN)[+] Done. Now run: make clean && make up$(NC)\n"

fix-permissions: acl ## Alias for 'acl'

use-rsync: ## Switch to rsync synced folder (recommended for troubleshooting)
	@printf "$(GREEN)[+] Switching to rsync synced folder...$(NC)\n"
	@cp Vagrantfile Vagrantfile.backup 2>/dev/null || true
	@cp Vagrantfile-rsync Vagrantfile
	@printf "$(GREEN)[+] Done! Now run 'make clean && make up'$(NC)\n"

use-nfs: ## Switch to NFS synced folder
	@printf "$(GREEN)[+] Switching to NFS synced folder...$(NC)\n"
	@sudo apt-get install -y nfs-kernel-server
	@cp Vagrantfile Vagrantfile.backup 2>/dev/null || true
	@cp Vagrantfile-nfs Vagrantfile
	@printf "$(GREEN)[+] Done! Now run 'make clean && make up'$(NC)\n"

up: ## Start both VMs (server and worker)
	@printf "$(GREEN)[+] Starting both VMs...$(NC)\n"
	@vagrant up $(SERVER_NAME)
	@vagrant up $(WORKER_NAME)
	@printf "$(GREEN)[+] Both VMs are up!$(NC)\n"

start: up ## Alias for 'up'

server: ## Start only the server VM
	@printf "$(GREEN)[+] Starting server VM...$(NC)\n"
	@vagrant up $(SERVER_NAME)

worker: ## Start only the worker VM (requires server to be running)
	@printf "$(GREEN)[+] Starting worker VM...$(NC)\n"
	@vagrant up $(WORKER_NAME)

ssh-server: ## SSH into the server VM
	@vagrant ssh $(SERVER_NAME)

ssh-worker: ## SSH into the worker VM
	@vagrant ssh $(WORKER_NAME)

status: ## Show status of all VMs
	@printf "$(GREEN)[+] VM Status:$(NC)\n"
	@vagrant status

check: ## Verify the cluster is working correctly
	@printf "$(GREEN)[+] Checking cluster status...$(NC)\n\n"
	@printf "$(YELLOW)Server VM:$(NC)\n"
	@vagrant ssh $(SERVER_NAME) -c "hostname && ip a show eth1 | grep 'inet ' && kubectl get nodes -o wide" || true
	@printf "\n$(YELLOW)Worker VM:$(NC)\n"
	@vagrant ssh $(WORKER_NAME) -c "hostname && ip a show eth1 | grep 'inet '" || true

test:
	@printf "[+] Running Part 1 Tests \n\n"
	@chmod +x ./TESTING.sh
	@./TESTING.sh

destroy: ## Destroy all VMs
	@printf "$(YELLOW)[!] Destroying all VMs...$(NC)\n"
	@vagrant destroy -f
	@printf "$(GREEN)[+] All VMs destroyed$(NC)\n"

clean: destroy ## Clean up everything (destroy VMs and clean vagrant data)
	@printf "$(YELLOW)[!] Cleaning up...$(NC)\n"
	@rm -rf .vagrant
	@rm -f confs/node-token confs/k3s.yaml
	@printf "$(GREEN)[+] Cleanup complete$(NC)\n"

re: clean up ## Rebuild everything from scratch

reload: ## Reload VMs (useful after config changes)
	@printf "$(GREEN)[+] Reloading VMs...$(NC)\n"
	@vagrant reload

provision: ## Re-run provisioning scripts
	@printf "$(GREEN)[+] Re-provisioning VMs...$(NC)\n"
	@vagrant provision

halt: ## Stop all VMs
	@printf "$(YELLOW)[!] Stopping all VMs...$(NC)\n"
	@vagrant halt

logs-server: ## Show server provisioning logs
	@vagrant ssh $(SERVER_NAME) -c "sudo journalctl -u k3s -n 50"

logs-worker: ## Show worker provisioning logs
	@vagrant ssh $(WORKER_NAME) -c "sudo journalctl -u k3s-agent -n 50"

.DEFAULT_GOAL := help
