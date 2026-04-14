#!/bin/bash
# Build and push the Fleet Dashboard app to ACR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
TF_DIR="$SCRIPT_DIR/../terraform"

# Get ACR login server from Terraform output
ACR_SERVER=$(cd "$TF_DIR" && terraform output -raw acr_login_server 2>/dev/null)
if [ -z "$ACR_SERVER" ]; then
    echo "❌ Could not get ACR login server. Run 'terraform apply' first."
    exit 1
fi

echo "📦 Building fleet-dashboard image..."
echo "   ACR: $ACR_SERVER"

# Login to ACR
az acr login --name "${ACR_SERVER%%.*}" 2>/dev/null

# Build and push
docker build -t "$ACR_SERVER/fleet-dashboard:v1" "$APP_DIR"
docker push "$ACR_SERVER/fleet-dashboard:v1"

echo ""
echo "✅ Image pushed: $ACR_SERVER/fleet-dashboard:v1"
echo ""
echo "Next: Update app/k8s/deployment.yaml with your ACR server:"
echo "  sed -i 's|<ACR_LOGIN_SERVER>|$ACR_SERVER|g' $APP_DIR/k8s/deployment.yaml"
