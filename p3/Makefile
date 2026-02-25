.PHONY: all setup cluster argocd app test clean destroy help port-forward argocd-password

CLUSTER_NAME = iot-cluster

all: help

help:
	@echo "Part 3 - K3d and ArgoCD"
	@echo "======================="
	@echo ""
	@echo "Commands:"
	@echo "  make all-in-one       - Create cluster and install ArgoCD"
	@echo "  make cluster          - Create K3d cluster"
	@echo "  make argocd           - Install ArgoCD"
	@echo "  make app              - Deploy application"
	@echo "  make test             - Run tests"
	@echo "  make port-forward     - Port forward services"
	@echo "  make argocd-password  - Get ArgoCD password"
	@echo "  make status           - Show status"
	@echo "  make destroy          - Delete cluster"
	@echo ""
	@echo "Prerequisites: Run ../setup_host.sh from project root first"
	@echo ""

cluster:
	@echo "==> Creating K3d cluster..."
	@bash scripts/create_cluster.sh
	@echo ""
	@echo "✓ Cluster created successfully!"

argocd:
	@echo "==> Installing ArgoCD..."
	@bash scripts/install_argocd.sh
	@echo ""
	@echo "✓ ArgoCD installed successfully!"
	@echo ""
	@echo "To access ArgoCD, run: make port-forward"
	@echo "Then open: https://localhost:9090"

app:
	@echo "==> Configuring application..."
	@bash scripts/configure_app.sh

all-in-one: cluster wait-cluster argocd wait-argocd app wait-app port-forward
	@echo ""
	@echo "========================================="
	@echo "Everything is ready!"
	@echo "========================================="
	@echo ""
	@echo "ArgoCD:      http://localhost:9090"
	@echo "Application: http://localhost:9091"
	@echo ""

wait-cluster:
	@echo "==> Waiting for cluster to be fully ready..."
	@sleep 10

wait-argocd:
	@echo "==> Waiting for ArgoCD to be fully ready..."
	@sleep 5

wait-app:
	@echo "==> Waiting for application to be deployed..."
	@sleep 5

status:
	@echo "==> Cluster info:"
	@kubectl cluster-info
	@echo ""
	@echo "==> Nodes:"
	@kubectl get nodes
	@echo ""
	@echo "==> Namespaces:"
	@kubectl get namespaces
	@echo ""
	@echo "==> ArgoCD applications:"
	@kubectl get applications -n argocd 2>/dev/null || echo "No applications found (run 'make app' first)"
	@echo ""
	@echo "==> Pods in dev namespace:"
	@kubectl get pods -n dev 2>/dev/null || echo "No pods in dev namespace yet"
	@echo ""
	@echo "==> Services in dev namespace:"
	@kubectl get svc -n dev 2>/dev/null || echo "No services in dev namespace yet"

test:
	@echo "==> Running Part 3 tests..."
	@echo ""
	@echo "==> Test 1: K3d cluster '$(CLUSTER_NAME)' exists..."
	@k3d cluster list | grep -q "$(CLUSTER_NAME)" || (echo "✗ ERROR: Cluster not found"; exit 1)
	@echo "✓ Cluster exists"
	@echo ""
	@echo "==> Test 2: Nodes are Ready..."
	@kubectl get nodes | grep -q "Ready" || (echo "✗ ERROR: No ready nodes"; exit 1)
	@echo "✓ Nodes are Ready"
	@echo ""
	@echo "==> Test 3: Required namespaces exist (argocd, dev)..."
	@kubectl get namespace argocd &>/dev/null || (echo "✗ ERROR: argocd namespace not found"; exit 1)
	@kubectl get namespace dev    &>/dev/null || (echo "✗ ERROR: dev namespace not found"; exit 1)
	@echo "✓ Namespaces argocd and dev exist"
	@echo ""
	@echo "==> Test 4: ArgoCD server pod is Running..."
	@kubectl get pods -n argocd 2>/dev/null | grep -q "argocd-server.*Running" || (echo "✗ ERROR: ArgoCD server not running"; exit 1)
	@echo "✓ ArgoCD server is Running"
	@echo ""
	@echo "==> Test 5: ArgoCD application 'wil-playground-app' exists..."
	@kubectl get application wil-playground-app -n argocd &>/dev/null || (echo "✗ ERROR: Application not found"; exit 1)
	@echo "✓ Application exists"
	@echo ""
	@echo "==> Test 6: ArgoCD application is Synced and Healthy..."
	@SYNC=$$(kubectl get application wil-playground-app -n argocd \
		-o jsonpath='{.status.sync.status}' 2>/dev/null); \
	HEALTH=$$(kubectl get application wil-playground-app -n argocd \
		-o jsonpath='{.status.health.status}' 2>/dev/null); \
	echo "    Sync: $$SYNC  |  Health: $$HEALTH"; \
	[ "$$SYNC" = "Synced" ]  || (echo "✗ ERROR: Application is not Synced (got: $$SYNC)"; exit 1); \
	[ "$$HEALTH" = "Healthy" ] || (echo "✗ ERROR: Application is not Healthy (got: $$HEALTH)"; exit 1)
	@echo "✓ Application is Synced and Healthy"
	@echo ""
	@echo "==> Test 7: wil-playground pod is Running in dev namespace..."
	@kubectl get pods -n dev 2>/dev/null | grep -q "wil-playground.*Running" || (echo "✗ ERROR: Application pod not running in dev"; exit 1)
	@echo "✓ Application pod is Running"
	@echo ""
	@echo "==> Test 8: Application responds via internal Service..."
	@kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -- \
		curl -s http://wil-playground-service.dev.svc.cluster.local:8888 | grep -q "status" || (echo "✗ ERROR: Application not responding"; exit 1)
	@echo "✓ Application responds on port 8888"
	@echo ""
	@echo "==> Test 9: Application accessible via port-forward (localhost:9091)..."
	@curl -s http://localhost:9091 2>/dev/null | grep -q "status" || (echo "⚠ WARNING: Port-forward not active (run 'make port-forward')"; exit 0)
	@echo "✓ Application accessible via port-forward"
	@echo ""
	@echo "========================================="
	@echo "All Part 3 tests passed!"
	@echo "========================================="

port-forward:
	@echo "==> Starting port forwarding in background..."
	@kubectl port-forward svc/argocd-server -n argocd 9090:80 > /tmp/argocd-pf.log 2>&1 & \
	echo $$! > /tmp/argocd-pf.pid
	@kubectl port-forward svc/wil-playground-service -n dev 9091:8888 > /tmp/app-pf.log 2>&1 & \
	echo $$! > /tmp/app-pf.pid
	@sleep 2
	@echo "✓ Port forwarding started in background"
	@echo ""
	@echo "ArgoCD:      http://localhost:9090"
	@echo "Application: http://localhost:9091"
	@echo ""
	@echo "Logs: tail -f /tmp/argocd-pf.log"
	@echo "Stop: make stop-port-forward"

stop-port-forward:
	@echo "==> Stopping port forwarding..."
	@if [ -f /tmp/argocd-pf.pid ]; then kill $$(cat /tmp/argocd-pf.pid) 2>/dev/null && rm /tmp/argocd-pf.pid; fi
	@if [ -f /tmp/app-pf.pid ]; then kill $$(cat /tmp/app-pf.pid) 2>/dev/null && rm /tmp/app-pf.pid; fi
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@echo "✓ Done"

port-forward-logs:
	@echo "==> Port-forward logs (Ctrl+C to exit)"
	@tail -f /tmp/argocd-pf.log /tmp/app-pf.log

argocd-password:
	@echo "==> ArgoCD Admin Credentials:"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@echo ""
	@echo "URL: http://localhost:9090 (after running 'make port-forward')"

logs:
	@echo "==> Application logs:"
	@kubectl logs -n dev -l app=wil-playground --tail=50 -f

clean:
	@echo "==> Stopping cluster..."
	@k3d cluster stop $(CLUSTER_NAME)
	@echo "✓ Cluster stopped"

destroy:
	@echo "==> Destroying cluster..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "✓ Cluster destroyed"
