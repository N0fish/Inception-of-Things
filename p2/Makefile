.PHONY: help preflight acl up status ssh destroy clean re

SHELL := /bin/bash
PROJECT_DIR := $(shell pwd)
HOSTS_LINE := 192.168.56.110 app1.com app2.com app3.com
HOSTS_IP := 192.168.56.110
HOSTS_NAMES := app1.com app2.com app3.com
HOSTS_MARKER := IOT_P2_APPS

GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

define DETECT_QEMU_USER
if getent passwd libvirt-qemu >/dev/null 2>&1; then echo libvirt-qemu; else echo qemu; fi
endef

help:
	@printf "$(GREEN)p2 targets$(NC)\n"
	@printf "  $(YELLOW)up$(NC)       preflight + vagrant up + vagrant provision\n"
	@printf "  $(YELLOW)ssh$(NC)      vagrant ssh\n"
	@printf "  $(YELLOW)status$(NC)   vagrant status\n"
	@printf "  $(YELLOW)destroy$(NC)  vagrant destroy -f\n"
	@printf "  $(YELLOW)clean$(NC)    destroy + remove .vagrant\n"
	@printf "  $(YELLOW)re$(NC)       clean then up\n"

preflight:
	@mkdir -p "$(PROJECT_DIR)/confs"
	@chmod 644 "$(PROJECT_DIR)"/confs/*.yaml 2>/dev/null || true
	@$(MAKE) acl

acl:
	@set -e; \
	QEMU_USER="$$($(DETECT_QEMU_USER))"; \
	printf "$(GREEN)[acl] Using qemu user: %s$(NC)\n" "$$QEMU_USER"; \
	\
	# allow traversal through parents (common if $HOME is 700)
	sudo setfacl -m u:$$QEMU_USER:--x "$$HOME" || true; \
	sudo setfacl -m u:$$QEMU_USER:--x "$$HOME/Documents" 2>/dev/null || true; \
	sudo setfacl -m u:$$QEMU_USER:--x "$$HOME/Documents/IOTwMake" 2>/dev/null || true; \
	\
	# allow qemu read/write to project + confs (recursive + default)
	sudo setfacl -m u:$$QEMU_USER:rwx  "$(PROJECT_DIR)"; \
	sudo setfacl -d -m u:$$QEMU_USER:rwx "$(PROJECT_DIR)"; \
	sudo setfacl -R -m u:$$QEMU_USER:rwx  "$(PROJECT_DIR)/confs"; \
	sudo setfacl -R -d -m u:$$QEMU_USER:rwx "$(PROJECT_DIR)/confs"; \
	printf "$(GREEN)[acl] Done$(NC)\n"


update-hosts:
	@printf "[hosts] Updating /etc/hosts...\n"
	@sudo sh -c 'grep -v "[[:space:]]# $(HOSTS_MARKER)$$" /etc/hosts > /tmp/hosts.iot && mv /tmp/hosts.iot /etc/hosts'
	@echo "$(HOSTS_IP) $(HOSTS_NAMES) # $(HOSTS_MARKER)" | sudo tee -a /etc/hosts >/dev/null
	@printf "[hosts] Done\n"

up: preflight update-hosts
	@printf "$(GREEN)[up] vagrant up...$(NC)\n"
	@vagrant up
	@printf "$(GREEN)[up] Done$(NC)\n"

status:
	@vagrant status

ssh:
	@vagrant ssh

destroy:
	@vagrant destroy -f

clean: destroy
	@rm -rf .vagrant

re: clean up
