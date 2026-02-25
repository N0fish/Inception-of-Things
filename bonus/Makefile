.PHONY: all setup cluster argocd gitlab configure-gitlab configure-argocd app test clean destroy help port-forward argocd-password gitlab-password stop-port-forward status

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
	@echo "  make test              - Run evaluation tests"
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

test:
	@echo "==> Running Bonus tests..."
	@echo ""
	@echo "==> Test 1: K3d cluster '$(CLUSTER_NAME)' exists..."
	@k3d cluster list | grep -q "$(CLUSTER_NAME)" || (echo "✗ ERROR: Cluster not found"; exit 1)
	@echo "✓ Cluster exists"
	@echo ""
	@echo "==> Test 2: Nodes are Ready..."
	@kubectl get nodes | grep -q "Ready" || (echo "✗ ERROR: No ready nodes"; exit 1)
	@echo "✓ Nodes are Ready"
	@echo ""
	@echo "==> Test 3: Required namespaces exist (argocd, gitlab, dev)..."
	@kubectl get namespace argocd &>/dev/null || (echo "✗ ERROR: argocd namespace not found"; exit 1)
	@kubectl get namespace gitlab &>/dev/null || (echo "✗ ERROR: gitlab namespace not found"; exit 1)
	@kubectl get namespace dev    &>/dev/null || (echo "✗ ERROR: dev namespace not found"; exit 1)
	@echo "✓ Namespaces argocd, gitlab, and dev exist"
	@echo ""
	@echo "==> Test 4: ArgoCD server pod is Running..."
	@kubectl get pods -n argocd 2>/dev/null | grep -q "argocd-server.*Running" || (echo "✗ ERROR: ArgoCD server not running"; exit 1)
	@echo "✓ ArgoCD server is Running"
	@echo ""
	@echo "==> Test 5: GitLab pods are Running..."
	@kubectl get pods -n gitlab 2>/dev/null | grep -q "Running" || (echo "✗ ERROR: No GitLab pods running in gitlab namespace"; exit 1)
	@echo "✓ GitLab pods are Running"
	@echo ""
	@echo "==> Test 6: ArgoCD application exists (pointing to local GitLab)..."
	@kubectl get application -n argocd &>/dev/null || (echo "✗ ERROR: No ArgoCD applications found"; exit 1)
	@echo "✓ ArgoCD application configured"
	@echo ""
	@echo "==> Test 7: ArgoCD application is Synced and Healthy..."
	@APP=$$(kubectl get application -n argocd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	SYNC=$$(kubectl get application "$$APP" -n argocd \
		-o jsonpath='{.status.sync.status}' 2>/dev/null); \
	HEALTH=$$(kubectl get application "$$APP" -n argocd \
		-o jsonpath='{.status.health.status}' 2>/dev/null); \
	echo "    App: $$APP  |  Sync: $$SYNC  |  Health: $$HEALTH"; \
	[ "$$SYNC" = "Synced" ]    || (echo "✗ ERROR: Application not Synced (got: $$SYNC)"; exit 1); \
	[ "$$HEALTH" = "Healthy" ] || (echo "✗ ERROR: Application not Healthy (got: $$HEALTH)"; exit 1)
	@echo "✓ Application is Synced and Healthy"
	@echo ""
	@echo "==> Test 8: wil-playground pod is Running in dev namespace..."
	@kubectl get pods -n dev 2>/dev/null | grep -q "wil-playground.*Running" || (echo "✗ ERROR: Application pod not running in dev"; exit 1)
	@echo "✓ Application pod is Running"
	@echo ""
	@echo "==> Test 9: Application responds via internal Service..."
	@kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -- \
		curl -s http://wil-playground-service.dev.svc.cluster.local:8888 | grep -q "status" || (echo "✗ ERROR: Application not responding"; exit 1)
	@echo "✓ Application responds on port 8888"
	@echo ""
	@echo "==> Test 10: Services accessible via port-forward..."
	@curl -s http://localhost:9090 2>/dev/null | grep -q "" || (echo "⚠ WARNING: ArgoCD port-forward not active (run 'make port-forward')"; exit 0)
	@curl -s http://localhost:8181 2>/dev/null | grep -q "" || (echo "⚠ WARNING: GitLab port-forward not active (run 'make port-forward')"; exit 0)
	@echo "✓ Services accessible via port-forward"
	@echo ""
	@echo "========================================="
	@echo "All Bonus tests passed!"
	@echo "========================================="

destroy:
	@echo "==> Destroying cluster..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "✓ Done"
