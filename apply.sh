#!/bin/bash
# ==============================================================================
# Build Pipeline Script: Mini-AD + RStudio Cluster on GCP (GKE version)
# ------------------------------------------------------------------------------
# Purpose:
#   - Automates the full deployment of the GKE-based RStudio environment
#   - Validates environment settings before proceeding
#   - Deploys Active Directory, supporting servers, Docker image, and GKE cluster
# ==============================================================================

set -e  # Exit immediately if any command returns a non-zero status

# ------------------------------------------------------------------------------
# Phase 0: Environment Check
# - Runs helper script to verify tools, vars, creds, and config files
# ------------------------------------------------------------------------------

./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Phase 1: Active Directory Deployment
# - Builds the Samba-based Mini-AD environment with Terraform
# ------------------------------------------------------------------------------

cd 01-directory

terraform init                # Load providers and backend
terraform apply -auto-approve # Deploy Mini-AD infra without prompts

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

cd ..  # Return to project root

# ------------------------------------------------------------------------------
# Phase 2: Server Deployment
# - Deploys Windows and Linux hosts joined to Mini-AD
# ------------------------------------------------------------------------------

cd 02-servers

terraform init                # Initialize server Terraform stack
terraform apply -auto-approve # Create server instances

cd ..  # Return to project root

# ------------------------------------------------------------------------------
# Phase 3: RStudio Docker Image Build
# - Builds and pushes the RStudio image used by GKE workloads
# ------------------------------------------------------------------------------

secretValue=$(gcloud secrets versions access latest --secret="rstudio-credentials")
RSTUDIO_PASSWORD=$(echo "$secretValue" | jq -r '.password')

if [ -z "$RSTUDIO_PASSWORD" ] || [ "$RSTUDIO_PASSWORD" = "null" ]; then
  echo "ERROR: Failed to retrieve RStudio password."
  exit 1
fi

cd "03-docker"
echo "NOTE: Building RStudio container for GKE deployment."

# Authenticate Docker to Google Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev -q

# Read project ID from local credentials file
project_id=$(jq -r '.project_id' "../credentials.json")

GCR_IMAGE=us-central1-docker.pkg.dev/$project_id/rstudio-repository/rstudio:rc1

# Check for existing image tag to avoid rebuilding
TAG_EXISTS=$(
  gcloud artifacts docker tags list \
    us-central1-docker.pkg.dev/$project_id/rstudio-repository/rstudio \
    --format="value(tag)" | grep -x "rc1" || true
)

if [[ -n "$TAG_EXISTS" ]]; then
  echo "NOTE: Image tag exists. Skipping Docker build."
else
  cd rstudio
  docker build \
    --build-arg RSTUDIO_PASSWORD="${RSTUDIO_PASSWORD}" \
    -t "$GCR_IMAGE" .
  docker push "$GCR_IMAGE"
  cd ..
fi

cd ..

# ------------------------------------------------------------------------------
# Phase 4: GKE Cluster Deployment
# - Deploys the Kubernetes cluster hosting RStudio
# ------------------------------------------------------------------------------

cd 04-gke

terraform init
terraform apply -auto-approve

export rstudio_image="${GCR_IMAGE}"
export project_id="${project_id}"

# Retrieve Filestore NFS endpoint for RStudio home dirs
export filestore_ip=$(
  gcloud filestore instances describe nfs-server \
    --zone=us-central1-b \
    --project="${project_id}" \
    --format="value(networks[0].ipAddresses[0])"
)

export filestore_share="filestore"

# Render Kubernetes deployment YAML from template
envsubst < yaml/rstudio-app.yaml.tmpl > ../rstudio-app.yaml || {
  echo "ERROR: Failed to generate k8s manifest. Exiting."
  exit 1
}

cd ..  # Return to project root

# ------------------------------------------------------------------------------
# Phase 5: Configure kubectl and Deploy YAML
# - Fetches GKE credentials and deploys the RStudio workloads
# ------------------------------------------------------------------------------

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

gcloud container clusters get-credentials rstudio-gke \
  --zone us-central1-a \
  --project "$project_id"

kubectl get nodes               # Confirm GKE nodes are available
kubectl apply -f rstudio-app.yaml  # Deploy RStudio to GKE

# ------------------------------------------------------------------------------
# Phase 6: Validation
# - Runs post-deployment checks for GKE environment readiness
# ------------------------------------------------------------------------------

./validate.sh
