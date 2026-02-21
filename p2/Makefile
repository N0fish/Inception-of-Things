.PHONY: help preflight acl update-hosts up status ssh destroy clean re

SHELL := /bin/bash
PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

HOSTS_IP := 192.168.56.110
HOSTS_NAMES := app1.com app2.com app3.com
HOSTS_MARKER := IOT_P2_APPS

GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help:
	@echo -e "$(GREEN)p2 targets$(NC)"
	@echo -e "  $(YELLOW)up$(NC)"
	@echo -e "  $(YELLOW)preflight$(NC)"
	@echo -e "  $(YELLOW)acl$(NC)"
	@echo -e "  $(YELLOW)update-hosts$(NC)"
	@echo -e "  $(YELLOW)ssh$(NC)"
	@echo -e "  $(YELLOW)status$(NC)"
	@echo -e "  $(YELLOW)destroy$(NC)"
	@echo -e "  $(YELLOW)clean$(NC)"
	@echo -e "  $(YELLOW)re$(NC)"

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
	echo -e "$(GREEN)[acl] Project: $$PROJ$(NC)"; \
	echo -e "$(GREEN)[acl] QEMU user: $$QEMU_USER$(NC)"; \
	P="$$PROJ"; \
	while [ "$$P" != "/" ]; do \
	  P="$$(dirname "$$P")"; \
	  sudo setfacl -m "u:$$QEMU_USER:--x" "$$P" 2>/dev/null || true; \
	done; \
	mkdir -p "$$PROJ/confs" "$$PROJ/scripts"; \
	sudo setfacl -m  "u:$$QEMU_USER:rwx" "$$PROJ"; \
	sudo setfacl -d -m "u:$$QEMU_USER:rwx" "$$PROJ"; \
	sudo setfacl -R -m  "u:$$QEMU_USER:rwx" "$$PROJ/confs" "$$PROJ/scripts"; \
	sudo setfacl -R -d -m "u:$$QEMU_USER:rwx" "$$PROJ/confs" "$$PROJ/scripts"; \
	echo -e "$(GREEN)[acl] Done$(NC)"

update-hosts:
	@echo "[hosts] Updating /etc/hosts..."
	@sudo sh -c 'tmp="$$(mktemp)"; \
	  grep -vE "[[:space:]]# $(HOSTS_MARKER)$$" /etc/hosts > "$$tmp"; \
	  echo "$(HOSTS_IP) $(HOSTS_NAMES) # $(HOSTS_MARKER)" >> "$$tmp"; \
	  cat "$$tmp" > /etc/hosts; \
	  rm -f "$$tmp"'
	@echo "[hosts] Done"

up: preflight update-hosts
	@echo -e "$(GREEN)[up] vagrant up...$(NC)"
	@vagrant up
	@echo -e "$(GREEN)[up] Done$(NC)"

status:
	@vagrant status

ssh:
	@vagrant ssh

destroy:
	@vagrant destroy -f

clean: destroy
	@rm -rf .vagrant

re: clean up