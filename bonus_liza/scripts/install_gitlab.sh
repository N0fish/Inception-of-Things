#!/bin/bash

set -e

echo "======================================"
echo "Installing GitLab CE (Latest Version)"
echo "======================================"
echo ""
echo "Using official gitlab/gitlab-ce:latest image"
echo "This is a minimal, single-container deployment"
echo ""

# Apply GitLab deployment
echo "==> Deploying GitLab..."
kubectl apply -f confs/gitlab/gitlab-deployment.yaml

echo ""
echo "==> GitLab deployment created"
echo "==> Waiting for GitLab pod to start (this takes 3-5 minutes)..."
echo ""

# Wait for pod to be created
sleep 10

# Wait for GitLab pod to be ready
echo "==> Waiting for GitLab container to be ready..."
kubectl wait --for=condition=Ready pod -l app=gitlab -n gitlab --timeout=600s 2>/dev/null || {
    echo "⚠️  GitLab taking longer than expected..."
    echo "GitLab container is initializing its database and services."
    echo "This can take 5-7 minutes on first start."
    echo ""
    echo "Current status:"
    kubectl get pods -n gitlab
    echo ""
    echo "You can monitor logs with:"
    echo "  kubectl logs -f -l app=gitlab -n gitlab"
    echo ""
    echo "Continuing to wait..."
    kubectl wait --for=condition=Ready pod -l app=gitlab -n gitlab --timeout=600s
}

echo ""
echo "==> GitLab pod status:"
kubectl get pods -n gitlab

echo ""
echo "==> GitLab service:"
kubectl get svc -n gitlab

# Check GitLab version
echo ""
echo "==> GitLab version:"
kubectl exec -n gitlab -l app=gitlab -- gitlab-rake gitlab:env:info | grep "GitLab information" -A 5 || echo "GitLab still initializing..."

echo ""
echo "====================================="
echo "GitLab Installation Complete!"
echo "====================================="
echo "Version: gitlab/gitlab-ce:latest"
echo "Username: root"
echo "Password: rootpassword123"
echo "====================================="
echo ""
echo "IMPORTANT: Wait 2-3 more minutes for GitLab to fully initialize"
echo "before creating repositories."
echo ""
echo "To access GitLab:"
echo "  kubectl port-forward svc/gitlab -n gitlab 8181:80"
echo "  Then open: http://localhost:8181"
echo ""
echo "To check if GitLab is ready:"
echo "  kubectl logs -l app=gitlab -n gitlab | grep 'gitlab Reconfigured!'"
echo ""
echo "Next step: make gitlab-config"
echo ""

