#!/bin/bash

set -e

# Install Helm if not present
if ! command -v helm &>/dev/null; then
  echo "==> Installing Helm..."
  sudo snap install helm --classic
fi

echo "==> Adding GitLab Helm repository..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "==> Creating gitlab namespace..."
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# values-minikube-minimum.yaml is maintained by GitLab alongside the chart —
# it always disables certmanager, TLS, prometheus, and gitlab-runner,
# sets minimal resources, and stays in sync with the latest chart version.
echo "==> Installing GitLab via Helm (5-10 minutes)..."
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml \
  --set global.hosts.domain=k3d.gitlab.com \
  --set global.hosts.externalIP=0.0.0.0 \
  --set global.hosts.https=false \
  --timeout 600s

echo "==> Waiting for GitLab webservice pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=webservice -n gitlab --timeout=3600s

echo ""
GITLAB_PASS=$(kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath="{.data.password}" | base64 -d)
echo "============================="
echo "GitLab Installation Complete!"
echo "============================="
echo "Username: root"
echo "Password: $GITLAB_PASS"
echo "Run 'make port-forward' then open: http://localhost:8181"
echo "============================="
echo ""
