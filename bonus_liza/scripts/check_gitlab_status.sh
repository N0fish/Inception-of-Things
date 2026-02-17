#!/bin/bash

echo "======================================"
echo "GitLab Status Check"
echo "======================================"
echo ""

# Check if gitlab namespace exists
if ! kubectl get namespace gitlab &>/dev/null; then
    echo "❌ GitLab namespace not found. Run 'make gitlab' first."
    exit 1
fi

echo "==> GitLab Namespace: ✓"
echo ""

# Check pods
echo "==> Pod Status:"
kubectl get pods -n gitlab

echo ""
echo "==> Detailed Status:"
echo ""

# Check GitLab pod
echo "GitLab Container:"
GITLAB_STATUS=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
GITLAB_READY=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
echo "  Status: $GITLAB_STATUS"
echo "  Ready: $GITLAB_READY"

if [ "$GITLAB_STATUS" != "Running" ]; then
    echo "  ⚠️  GitLab not running"
    echo ""
    echo "  Checking recent events:"
    kubectl get events -n gitlab --sort-by='.lastTimestamp' | tail -10
elif [ "$GITLAB_READY" != "true" ]; then
    echo "  ⚠️  GitLab container not ready yet"
    echo ""
    echo "  Checking initialization logs:"
    kubectl logs -n gitlab -l app=gitlab --tail=30 | grep -E "(gitlab|reconfigure|started|ready|error)" || echo "  Still initializing..."
fi

# Check GitLab version
if [ "$GITLAB_READY" = "true" ]; then
    echo ""
    echo "==> GitLab Version:"
    kubectl exec -n gitlab -l app=gitlab -- cat /opt/gitlab/version-manifest.txt 2>/dev/null | head -1 || echo "  Version info not available yet"
fi

# Check service
echo ""
echo "==> Service:"
kubectl get svc -n gitlab

echo ""
echo "==> Summary:"
echo ""

if [ "$GITLAB_READY" = "true" ]; then
    echo "✅ GitLab is fully operational!"
    echo ""
    echo "GitLab Info:"
    echo "  Username: root"
    echo "  Password: rootpassword123"
    echo "  Image: gitlab/gitlab-ce:latest"
    echo ""
    echo "Next steps:"
    echo "  1. Run: make gitlab-config"
    echo "  2. Run: make app"
    echo "  3. Run: make port-forward"
else
    echo "⚠️  GitLab is not fully ready yet."
    echo ""
    if [ "$GITLAB_STATUS" = "Running" ]; then
        echo "✓ Pod is Running - GitLab is initializing its services"
        echo "  This typically takes 3-5 minutes on first start"
        echo ""
        echo "  To check progress:"
        echo "    kubectl logs -f -l app=gitlab -n gitlab | grep -i reconfigured"
        echo ""
        echo "  Look for: 'gitlab Reconfigured!'"
    else
        echo "Common issues:"
        echo "  1. Pod pending → Check resources: kubectl describe pod -l app=gitlab -n gitlab"
        echo "  2. Pod crashing → Check logs: kubectl logs -l app=gitlab -n gitlab --tail=100"
        echo "  3. Insufficient resources → GitLab needs 2GB+ RAM, 1+ CPU"
        echo ""
        echo "Troubleshooting commands:"
        echo "  kubectl get pods -n gitlab"
        echo "  kubectl describe pod -l app=gitlab -n gitlab"
        echo "  kubectl logs -l app=gitlab -n gitlab --tail=100"
        echo ""
        echo "If issues persist:"
        echo "  1. Delete: make destroy"
        echo "  2. Recreate: make cluster && make argocd && make gitlab"
    fi
fi

echo ""
echo "To monitor in real-time:"
echo "  watch kubectl get pods -n gitlab"
echo "  kubectl logs -f -l app=gitlab -n gitlab"
