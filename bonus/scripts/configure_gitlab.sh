#!/bin/bash

set -e

PROJECT_NAME="iot-playground"

# The initial root password is stored in a secret created by the Helm chart.
GITLAB_PASS=$(kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath="{.data.password}" | base64 -d)

# Create a personal access token via the toolbox pod (gitlab-rails runner).
# This is the only reliable method — GitLab API requires an existing token
# to create a new one, and /api/v4/session was removed in GitLab 10.0.
echo "==> Creating access token via gitlab-rails runner..."
TOOLBOX=$(kubectl get pod -n gitlab -l app=toolbox \
  -o jsonpath='{.items[0].metadata.name}')

GITLAB_TOKEN=$(kubectl exec -n gitlab "$TOOLBOX" -- gitlab-rails runner \
  "t = User.find_by_username('root').personal_access_tokens.create(\
    name: 'argocd', \
    scopes: [:api, :read_repository, :write_repository], \
    expires_at: 1.year.from_now); \
  puts t.token" 2>/dev/null | tail -1)

if [ -z "$GITLAB_TOKEN" ]; then
  echo "ERROR: Could not create access token"
  exit 1
fi

# Persist for configure_argocd.sh — Make runs each target in a separate
# subprocess so env vars cannot be passed between targets.
echo "$GITLAB_TOKEN" > /tmp/gitlab-token
echo "==> Token created"

# Port-forward the webservice for API access
echo "==> Port-forwarding GitLab webservice..."
kubectl port-forward svc/gitlab-webservice-default -n gitlab 8181:8181 \
  >/dev/null 2>&1 &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 5

echo "==> Waiting for GitLab API..."
for i in $(seq 1 12); do
  curl -sf "http://localhost:8181/-/health" >/dev/null && break
  [ "$i" -eq 12 ] && { echo "ERROR: GitLab API not responding after 60s"; exit 1; }
  sleep 5
done

# Create the project as public so ArgoCD can reach it without credentials
echo "==> Creating project '$PROJECT_NAME'..."
PROJECT_ID=$(curl -sf \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$PROJECT_NAME\",\"visibility\":\"public\"}" \
  "http://localhost:8181/api/v4/projects" \
  | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)

if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Could not create project"
  exit 1
fi
echo "==> Project created (ID: $PROJECT_ID)"

# Push deployment.yaml as the initial commit on main branch
echo "==> Pushing deployment.yaml to repository..."
CONTENT=$(base64 -w0 < confs/app/deployment.yaml)
curl -sf \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"branch\":\"main\",\"commit_message\":\"v1\",\"encoding\":\"base64\",\"content\":\"$CONTENT\"}" \
  "http://localhost:8181/api/v4/projects/$PROJECT_ID/repository/files/deployment.yaml" \
  >/dev/null

echo ""
echo "==> Repository ready: http://localhost:8181/root/$PROJECT_NAME"
echo ""
