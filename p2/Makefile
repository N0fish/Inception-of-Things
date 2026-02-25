.PHONY: help preflight acl update-hosts up status ssh check test halt logs destroy clean re

SHELL       := /bin/bash
PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

LOGIN        := urosby
SERVER_NAME  := $(LOGIN)S
SERVER_IP    := 192.168.56.110
HOSTS_NAMES  := app1.com app2.com app3.com
HOSTS_MARKER := IOT_P2_APPS

GREEN  := \033[0;32m
YELLOW := \033[1;33m
NC     := \033[0m

help: 
	@printf "$(GREEN)Inception-of-Things Part 2 - Makefile$(NC)\n\n"
	@printf "Available targets:\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-18s$(NC) %s\n", $$1, $$2}'
	@printf "\n"

preflight: 
	@mkdir -p "$(PROJECT_DIR)/confs" "$(PROJECT_DIR)/scripts"
	@$(MAKE) acl

acl: 
	@set -euo pipefail; \
	PROJ="$(PROJECT_DIR)"; \
	QEMU_USER="$$( \
	  if getent passwd libvirt-qemu >/dev/null 2>&1; then echo libvirt-qemu; \
	  elif getent passwd "libvirt+" >/dev/null 2>&1; then echo "libvirt+"; \
	  elif getent passwd qemu >/dev/null 2>&1; then echo qemu; \
	  else echo libvirt-qemu; fi \
	)"; \
	printf "$(GREEN)[acl] Project : $$PROJ$(NC)\n"; \
	printf "$(GREEN)[acl] QEMU user: $$QEMU_USER$(NC)\n"; \
	P="$$PROJ"; \
	while [ "$$P" != "/" ]; do \
	  P="$$(dirname "$$P")"; \
	  sudo setfacl -m "u:$$QEMU_USER:--x" "$$P" 2>/dev/null || true; \
	done; \
	mkdir -p "$$PROJ/confs" "$$PROJ/scripts"; \
	sudo setfacl -m    "u:$$QEMU_USER:rwx" "$$PROJ"; \
	sudo setfacl -d -m "u:$$QEMU_USER:rwx" "$$PROJ"; \
	sudo setfacl -R -m    "u:$$QEMU_USER:rwx" "$$PROJ/confs" "$$PROJ/scripts"; \
	sudo setfacl -R -d -m "u:$$QEMU_USER:rwx" "$$PROJ/confs" "$$PROJ/scripts"; \
	printf "$(GREEN)[acl] Done$(NC)\n"

update-hosts: 
	@echo "[hosts] Updating /etc/hosts..."
	@sudo sh -c 'tmp="$$(mktemp)"; \
	  grep -vE "[[:space:]]# $(HOSTS_MARKER)$$" /etc/hosts > "$$tmp"; \
	  echo "$(SERVER_IP) $(HOSTS_NAMES) # $(HOSTS_MARKER)" >> "$$tmp"; \
	  cat "$$tmp" > /etc/hosts; \
	  rm -f "$$tmp"'
	@echo "[hosts] Done"

up: preflight update-hosts 
	@printf "$(GREEN)[up] Starting VM...$(NC)\n"
	@vagrant up
	@printf "$(GREEN)[up] Done$(NC)\n"

status: 
	@vagrant status

ssh: 
	@vagrant ssh

check:
	@printf "$(GREEN)[+] Nodes:$(NC)\n"
	@vagrant ssh $(SERVER_NAME) -c "kubectl get nodes -o wide" 2>/dev/null || true
	@echo ""
	@printf "$(GREEN)[+] Pods (all namespaces):$(NC)\n"
	@vagrant ssh $(SERVER_NAME) -c "kubectl get pods -A" 2>/dev/null || true
	@echo ""
	@printf "$(GREEN)[+] Ingress rules:$(NC)\n"
	@vagrant ssh $(SERVER_NAME) -c "kubectl get ingress -A" 2>/dev/null || true
	@echo ""
	@printf "$(GREEN)[+] Services:$(NC)\n"
	@vagrant ssh $(SERVER_NAME) -c "kubectl get svc" 2>/dev/null || true

test: 
	@printf "$(GREEN)[+] Running Part 2 tests...$(NC)\n"
	@chmod +x ./test.sh
	@./test.sh

halt: 
	@printf "$(YELLOW)[!] Stopping VM...$(NC)\n"
	@vagrant halt

logs: 
	@vagrant ssh $(SERVER_NAME) -c "sudo journalctl -u k3s -n 50"

destroy: 
	@printf "$(YELLOW)[!] Destroying VM...$(NC)\n"
	@vagrant destroy -f
	@printf "$(GREEN)[+] VM destroyed$(NC)\n"

clean: destroy 
	@printf "$(YELLOW)[!] Cleaning up...$(NC)\n"
	@rm -rf .vagrant
	@printf "$(GREEN)[+] Cleanup complete$(NC)\n"

re: clean up 

.DEFAULT_GOAL := help
