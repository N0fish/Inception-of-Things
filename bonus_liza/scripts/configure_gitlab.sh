#!/bin/bash

set -e

echo "======================================"
echo "Configuring GitLab Repository"
echo "======================================"
echo ""

GITLAB_PASSWORD="rootpassword123"
PROJECT_NAME="iot-playground"

# Forward GitLab port for API access
echo "==> Setting up port forward to GitLab..."
kubectl port-forward svc/gitlab -n gitlab 8181:80 > /tmp/gitlab-pf.log 2>&1 &
PF_PID=$!
echo $PF_PID > /tmp/gitlab-pf.pid

# Wait for port forward to be ready
echo "==> Waiting for GitLab to be accessible..."
sleep 5

# Test GitLab API connection
echo "==> Testing GitLab API..."
for i in {1..20}; do
    if curl -s http://localhost:8181/-/health > /dev/null 2>&1; then
        echo "✓ GitLab is accessible"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ ERROR: GitLab not responding. Make sure GitLab is fully started."
        kill $PF_PID 2>/dev/null || true
        exit 1
    fi
    echo "Waiting for GitLab API ($i/20)..."
    sleep 3
done

# Create personal access token using GitLab API
echo ""
echo "==> Creating personal access token..."
TOKEN_RESPONSE=$(curl -s -X POST "http://localhost:8181/api/v4/users/1/personal_access_tokens" \
  --header "PRIVATE-TOKEN: $(echo -n "root:${GITLAB_PASSWORD}" | base64)" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "argocd-token",
    "scopes": ["api", "read_repository", "write_repository"],
    "expires_at": "2030-01-01"
  }' 2>/dev/null)

# Get root user session token
echo "==> Logging in as root..."
SESSION_RESPONSE=$(curl -s -X POST "http://localhost:8181/api/v4/session" \
  --data "login=root&password=${GITLAB_PASSWORD}")

GITLAB_TOKEN=$(echo $SESSION_RESPONSE | grep -o '"private_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$GITLAB_TOKEN" ]; then
    echo "⚠️  Could not get token via API, using kubectl exec method..."

    # Alternative: Create token via GitLab Rails console
    GITLAB_POD=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}')

    GITLAB_TOKEN=$(kubectl exec -n gitlab $GITLAB_POD -- gitlab-rails runner "
      user = User.find_by_username('root')
      token = user.personal_access_tokens.create(
        name: 'argocd-token',
        scopes: [:api, :read_repository, :write_repository],
        expires_at: 365.days.from_now
      )
      puts token.token
    " 2>/dev/null | tail -1)
fi

echo "✓ Token created: ${GITLAB_TOKEN:0:10}..."

# Create project
echo ""
echo "==> Creating project '$PROJECT_NAME'..."
PROJECT_RESPONSE=$(curl -s -X POST "http://localhost:8181/api/v4/projects" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"name\": \"$PROJECT_NAME\",
    \"visibility\": \"public\",
    \"initialize_with_readme\": false
  }")

PROJECT_ID=$(echo $PROJECT_RESPONSE | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$PROJECT_ID" ]; then
    echo "❌ ERROR: Could not create project"
    echo "Response: $PROJECT_RESPONSE"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

echo "✓ Project created with ID: $PROJECT_ID"

# Add deployment.yaml file
echo ""
echo "==> Adding deployment.yaml to repository..."
DEPLOYMENT_CONTENT=$(base64 -w 0 < confs/app/deployment.yaml)

FILE_RESPONSE=$(curl -s -X POST "http://localhost:8181/api/v4/projects/$PROJECT_ID/repository/files/deployment.yaml" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data "{
    \"branch\": \"main\",
    \"content\": \"$DEPLOYMENT_CONTENT\",
    \"commit_message\": \"Initial commit: deployment.yaml v1\",
    \"encoding\": \"base64\"
  }")

if echo "$FILE_RESPONSE" | grep -q "file_path"; then
    echo "✓ deployment.yaml added successfully"
else
    echo "⚠️  Warning: File creation response: $FILE_RESPONSE"
fi

GITLAB_URL="http://gitlab.gitlab.svc.cluster.local"
PROJECT_URL="$GITLAB_URL/root/$PROJECT_NAME.git"

echo ""
echo "====================================="
echo "GitLab Repository Configured!"
echo "====================================="
echo "Project: $PROJECT_NAME"
echo "Project ID: $PROJECT_ID"
echo "URL: $PROJECT_URL"
echo "Token: $GITLAB_TOKEN"
echo "====================================="
echo ""
echo "Repository URL (internal): $PROJECT_URL"
echo "Web URL: http://localhost:8181/root/$PROJECT_NAME"
echo ""
echo "Next step: make app"
echo ""

# Stop port forward
if [ -f /tmp/gitlab-pf.pid ]; then
    kill $(cat /tmp/gitlab-pf.pid) 2>/dev/null || true
    rm /tmp/gitlab-pf.pid
fi
