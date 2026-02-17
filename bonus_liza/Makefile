.PHONY: all setup cluster argocd gitlab gitlab-status app test clean destroy help port-forward argocd-password gitlab-password

CLUSTER_NAME = iot-cluster

all: help

help:
	@echo "BONUS - K3d, ArgoCD and GitLab"
	@echo "=============================="
	@echo ""
	@echo "Commands:"
	@echo "  make all-in-one        - Create cluster, install ArgoCD and GitLab"
	@echo "  make cluster           - Create K3d cluster"
	@echo "  make argocd            - Install ArgoCD"
	@echo "  make gitlab            - Install GitLab"
	@echo "  make gitlab-status     - Check GitLab installation status"
	@echo "  make gitlab-config     - Configure GitLab repository"
	@echo "  make app               - Deploy application with GitLab"
	@echo "  make test              - Run tests"
	@echo "  make port-forward      - Port forward services"
	@echo "  make argocd-password   - Get ArgoCD password"
	@echo "  make gitlab-password   - Get GitLab password"
	@echo "  make status            - Show status"
	@echo "  make destroy           - Delete cluster"
	@echo ""
	@echo "Prerequisites: Run ./setup_host.sh first to install Helm"
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

gitlab:
	@echo "==> Installing GitLab (this takes 5-10 minutes)..."
	@bash scripts/install_gitlab.sh
	@echo ""
	@echo "✓ GitLab installed successfully!"
	@echo ""

gitlab-status:
	@bash scripts/check_gitlab_status.sh

gitlab-config:
	@echo "==> Configuring GitLab repository..."
	@bash scripts/configure_gitlab.sh
	@echo ""
	@echo "✓ GitLab repository configured!"
	@echo ""

app:
	@echo "==> Configuring application with GitLab..."
	@bash scripts/configure_app.sh

all-in-one: cluster wait-cluster argocd wait-argocd gitlab wait-gitlab gitlab-config wait-config app wait-app port-forward
	@echo ""
	@echo "========================================="
	@echo "BONUS: Everything is ready!"
	@echo "========================================="
	@echo ""
	@echo "ArgoCD:      http://localhost:9090"
	@echo "GitLab:      http://localhost:8181"
	@echo "Application: http://localhost:9091"
	@echo ""
	@echo "Use 'make argocd-password' and 'make gitlab-password' to get credentials"
	@echo ""

wait-cluster:
	@echo "==> Waiting for cluster to be fully ready..."
	@sleep 10

wait-argocd:
	@echo "==> Waiting for ArgoCD to be fully ready..."
	@sleep 5

wait-gitlab:
	@echo "==> Waiting for GitLab to be fully ready (this can take several minutes)..."
	@sleep 30

wait-config:
	@echo "==> Waiting for GitLab configuration..."
	@sleep 10

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
	@echo "==> GitLab pods:"
	@kubectl get pods -n gitlab 2>/dev/null || echo "GitLab not installed yet"
	@echo ""
	@echo "==> Pods in dev namespace:"
	@kubectl get pods -n dev 2>/dev/null || echo "No pods in dev namespace yet"
	@echo ""
	@echo "==> Services in dev namespace:"
	@kubectl get svc -n dev 2>/dev/null || echo "No services in dev namespace yet"

test:
	@echo "==> Running BONUS tests..."
	@echo ""
	@echo "==> Test 1: Checking K3d cluster..."
	@k3d cluster list | grep -q "$(CLUSTER_NAME)" || (echo "✗ ERROR: Cluster not found"; exit 1)
	@echo "✓ Cluster exists"
	@echo ""
	@echo "==> Test 2: Checking nodes..."
	@kubectl get nodes | grep -q "Ready" || (echo "✗ ERROR: No ready nodes"; exit 1)
	@echo "✓ Nodes are Ready"
	@echo ""
	@echo "==> Test 3: Checking namespaces..."
	@kubectl get namespace argocd &>/dev/null || (echo "✗ ERROR: argocd namespace not found"; exit 1)
	@kubectl get namespace gitlab &>/dev/null || (echo "✗ ERROR: gitlab namespace not found"; exit 1)
	@kubectl get namespace dev &>/dev/null || (echo "✗ ERROR: dev namespace not found"; exit 1)
	@echo "✓ Required namespaces exist (argocd, gitlab, dev)"
	@echo ""
	@echo "==> Test 4: Checking ArgoCD installation..."
	@kubectl get pods -n argocd 2>/dev/null | grep -q "argocd-server.*Running" || (echo "✗ ERROR: ArgoCD server not running"; exit 1)
	@echo "✓ ArgoCD is running"
	@echo ""
	@echo "==> Test 5: Checking GitLab installation..."
	@kubectl get pods -n gitlab 2>/dev/null | grep -q "gitlab.*Running" || (echo "✗ ERROR: GitLab not running"; exit 1)
	@echo "✓ GitLab is running"
	@echo ""
	@echo "==> Test 6: Checking application..."
	@kubectl get application wil-playground-app -n argocd &>/dev/null || (echo "✗ ERROR: Application not found"; exit 1)
	@echo "✓ Application exists"
	@echo ""
	@echo "==> Test 7: Checking pods in dev namespace..."
	@kubectl get pods -n dev 2>/dev/null | grep -q "wil-playground.*Running" || (echo "✗ ERROR: Application pod not running"; exit 1)
	@echo "✓ Application pod is running"
	@echo ""
	@echo "==> Test 8: Testing application via Service..."
	@kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -- \
		curl -s http://wil-playground-service.dev.svc.cluster.local:8888 | grep -q "status" || (echo "✗ ERROR: Application not responding"; exit 1)
	@echo "✓ Application is responding"
	@echo ""
	@echo "==> Test 9: Verifying GitLab repository connection..."
	@kubectl get secret gitlab-repo-creds -n argocd &>/dev/null || (echo "✗ ERROR: GitLab credentials not configured"; exit 1)
	@echo "✓ GitLab repository credentials configured"
	@echo ""
	@echo "========================================="
	@echo "All BONUS tests passed!"
	@echo "========================================="

port-forward:
	@echo "==> Starting port forwarding in background..."
	@kubectl port-forward svc/argocd-server -n argocd 9090:80 > /tmp/argocd-pf.log 2>&1 & \
	echo $$! > /tmp/argocd-pf.pid
	@kubectl port-forward svc/gitlab -n gitlab 8181:80 > /tmp/gitlab-pf.log 2>&1 & \
	echo $$! > /tmp/gitlab-pf.pid
	@kubectl port-forward svc/wil-playground-service -n dev 9091:8888 > /tmp/app-pf.log 2>&1 & \
	echo $$! > /tmp/app-pf.pid
	@sleep 2
	@echo "✓ Port forwarding started in background"
	@echo ""
	@echo "ArgoCD:      http://localhost:9090"
	@echo "GitLab:      http://localhost:8181"
	@echo "Application: http://localhost:9091"
	@echo ""
	@echo "Stop: make stop-port-forward"

stop-port-forward:
	@echo "==> Stopping port forwarding..."
	@if [ -f /tmp/argocd-pf.pid ]; then kill $$(cat /tmp/argocd-pf.pid) 2>/dev/null && rm /tmp/argocd-pf.pid; fi
	@if [ -f /tmp/gitlab-pf.pid ]; then kill $$(cat /tmp/gitlab-pf.pid) 2>/dev/null && rm /tmp/gitlab-pf.pid; fi
	@if [ -f /tmp/app-pf.pid ]; then kill $$(cat /tmp/app-pf.pid) 2>/dev/null && rm /tmp/app-pf.pid; fi
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@echo "✓ Done"

port-forward-logs:
	@echo "==> Port-forward logs (Ctrl+C to exit)"
	@tail -f /tmp/argocd-pf.log /tmp/gitlab-pf.log /tmp/app-pf.log

argocd-password:
	@echo "==> ArgoCD Admin Credentials:"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
	@echo ""
	@echo "URL: http://localhost:9090 (after running 'make port-forward')"

gitlab-password:
	@echo "==> GitLab Root Credentials:"
	@echo "Username: root"
	@echo "Password: rootpassword123"
	@echo ""
	@echo "URL: http://localhost:8181 (after running 'make port-forward')"
	@echo ""
	@echo "GitLab Image: gitlab/gitlab-ce:latest"

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
