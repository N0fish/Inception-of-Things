#!/bin/bash

set -e

# Token was written to file by configure_gitlab.sh.
# Make runs each target in a separate subprocess — env vars don't cross.
GITLAB_TOKEN=$(cat /tmp/gitlab-token)

if [ -z "$GITLAB_TOKEN" ]; then
  echo "ERROR: No token at /tmp/gitlab-token. Run 'make configure-gitlab' first."
  exit 1
fi

echo "==> Adding GitLab repository credentials to ArgoCD..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: http://gitlab-webservice-default.gitlab.svc:8181/root/iot-playground.git
  username: root
  password: "$GITLAB_TOKEN"
EOF

echo "==> Deploying ArgoCD application pointing to local GitLab..."
kubectl apply -f confs/application-gitlab.yaml

echo "==> Waiting for application pod..."
kubectl wait --for=condition=Ready pod -l app=wil-playground -n dev \
  --timeout=180s 2>/dev/null || echo "Pod starting — ArgoCD is syncing..."

echo ""
kubectl get application -n argocd
echo ""
kubectl get pods -n dev
echo ""
