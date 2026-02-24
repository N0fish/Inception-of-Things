.PHONY: all setup cluster argocd gitlab configure-gitlab configure-argocd app test clean destroy help port-forward argocd-password gitlab-password

CLUSTER_NAME = iot-cluster

all: help

help:
	@echo "Bonus - K3d, ArgoCD and GitLab"
	@echo "==============================="
	@echo ""
	@echo "Commands:"
	@echo "  make all-in-one        - Full setup: cluster + ArgoCD + GitLab + app"
	@echo "  make cluster           - Create K3d cluster"
	@echo "  make argocd            - Install ArgoCD"
	@echo "  make gitlab            - Install GitLab via Helm"
	@echo "  make configure-gitlab  - Create GitLab repo and push deployment"
	@echo "  make configure-argocd  - Point ArgoCD to local GitLab"
	@echo "  make port-forward      - Forward ports for all services"
	@echo "  make argocd-password   - Get ArgoCD admin password"
	@echo "  make gitlab-password   - Get GitLab root password"
	@echo "  make status            - Show cluster and pod status"
	@echo "  make destroy           - Delete cluster"
	@echo ""
	@echo "Prerequisites: Run ./setup_host.sh first"
	@echo ""

cluster:
	@echo "==> Creating K3d cluster..."
	@bash scripts/create_cluster.sh
	@echo ""
	@echo "✓ Cluster created!"

argocd:
	@echo "==> Installing ArgoCD..."
	@bash scripts/install_argocd.sh
	@echo ""
	@echo "✓ ArgoCD installed!"

gitlab:
	@echo "==> Installing GitLab (5-10 minutes)..."
	@bash scripts/install_gitlab.sh
	@echo ""
	@echo "✓ GitLab installed!"

configure-gitlab:
	@echo "==> Configuring GitLab repository..."
	@bash scripts/configure_gitlab.sh
	@echo ""
	@echo "✓ GitLab repository configured!"

configure-argocd:
	@echo "==> Configuring ArgoCD to use local GitLab..."
	@bash scripts/configure_argocd.sh
	@echo ""
	@echo "✓ ArgoCD configured!"

all-in-one: cluster argocd gitlab configure-gitlab configure-argocd port-forward
	@echo ""
	@echo "========================================="
	@echo "BONUS: Everything is ready!"
	@echo "========================================="
	@echo ""
	@echo "ArgoCD:      http://localhost:9090"
	@echo "GitLab:      http://localhost:8181"
	@echo "Application: http://localhost:9091"
	@echo ""

port-forward:
	@echo "==> Starting port forwarding..."
	@kubectl port-forward svc/argocd-server -n argocd 9090:80 \
		>/tmp/argocd-pf.log 2>&1 & echo $$! > /tmp/argocd-pf.pid
	@kubectl port-forward svc/gitlab-webservice-default -n gitlab 8181:8181 \
		>/tmp/gitlab-pf.log 2>&1 & echo $$! > /tmp/gitlab-pf.pid
	@echo "==> Waiting for application service to be ready..."
	@kubectl wait --for=condition=Ready pod -l app=wil-playground -n dev --timeout=120s 2>/dev/null || true
	@kubectl port-forward svc/wil-playground-service -n dev 9091:8888 \
		>/tmp/app-pf.log 2>&1 & echo $$! > /tmp/app-pf.pid
	@sleep 2
	@echo "✓ Port forwarding started"
	@echo ""
	@echo "ArgoCD:      http://localhost:9090"
	@echo "GitLab:      http://localhost:8181"
	@echo "Application: http://localhost:9091"
	@echo ""
	@echo "Stop: make stop-port-forward"

stop-port-forward:
	@if [ -f /tmp/argocd-pf.pid ]; then kill $$(cat /tmp/argocd-pf.pid) 2>/dev/null; rm /tmp/argocd-pf.pid; fi
	@if [ -f /tmp/gitlab-pf.pid ]; then kill $$(cat /tmp/gitlab-pf.pid) 2>/dev/null; rm /tmp/gitlab-pf.pid; fi
	@if [ -f /tmp/app-pf.pid ]; then kill $$(cat /tmp/app-pf.pid) 2>/dev/null; rm /tmp/app-pf.pid; fi
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@echo "✓ Done"

argocd-password:
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d)"
	@echo "URL: http://localhost:9090"

gitlab-password:
	@echo "Username: root"
	@echo "Password: $$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password \
		-o jsonpath='{.data.password}' | base64 -d)"
	@echo "URL: http://localhost:8181"

status:
	@echo "==> Nodes:"
	@kubectl get nodes
	@echo ""
	@echo "==> Namespaces:"
	@kubectl get namespaces
	@echo ""
	@echo "==> GitLab pods:"
	@kubectl get pods -n gitlab 2>/dev/null || echo "GitLab not installed"
	@echo ""
	@echo "==> ArgoCD pods:"
	@kubectl get pods -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "==> Application:"
	@kubectl get application -n argocd 2>/dev/null || echo "No application"
	@echo ""
	@echo "==> Dev pods:"
	@kubectl get pods -n dev 2>/dev/null || echo "No pods in dev"

destroy:
	@echo "==> Destroying cluster..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "✓ Done"
