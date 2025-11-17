#!/bin/bash
# ==========================================================================================
# Build Pipeline Script: Mini-AD + RStudio Cluster on GCP
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Orchestrates multi-phase deployment using Terraform and Packer
#   - Ensures environment validation before execution
#   - Builds Active Directory, servers, custom RStudio image, and cluster
# ==========================================================================================

set -e  # Exit immediately on any unhandled command failure

# ------------------------------------------------------------------------------------------
# Phase 0: Environment Check
# - Runs a helper script to verify required environment variables, tools, and configs
# ------------------------------------------------------------------------------------------

./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi


# ------------------------------------------------------------------------------------------
# Phase 1: Active Directory Deployment
# - Provisions Samba-based Active Directory using Terraform
# ------------------------------------------------------------------------------------------
cd 01-directory

terraform init                # Initialize Terraform providers and backend
terraform apply -auto-approve # Apply configuration without manual approval

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

cd .. # Return to project root

# ------------------------------------------------------------------------------------------
# Phase 2: Server Deployment
# - Provisions Windows and Linux clients joined to Active Directory
# ------------------------------------------------------------------------------------------

cd 02-servers

terraform init                # Initialize Terraform for server provisioning
terraform apply -auto-approve # Deploy server infrastructure

cd .. # Return to project root


# ------------------------------------------------------------------------------------------
# Phase 3: RStudio Docker Image Build
# - Builds a custom Docker image with RStudio
# ------------------------------------------------------------------------------------------

secretValue=$(gcloud secrets versions access latest --secret="rstudio-credentials")
RSTUDIO_PASSWORD=$(echo $secretValue | jq -r '.password')      # Extract password

if [ -z "$RSTUDIO_PASSWORD" ] || [ "$RSTUDIO_PASSWORD" = "null" ]; then
  echo "ERROR: Failed to retrieve RStudio password."
  exit 1
fi


# Move into the Docker setup directory where all container builds occur.
cd "03-docker"
echo "NOTE: Building rstudio container with Docker."

# Authenticate Docker with Google Artifact Registry for the specified region.
gcloud auth configure-docker us-central1-docker.pkg.dev -q 

# Extract the GCP project ID from the credentials JSON file.
project_id=$(jq -r '.project_id' "../credentials.json")

GCR_IMAGE=us-central1-docker.pkg.dev/$project_id/rstudio-repository/rstudio:rc1

TAG_EXISTS=$(
  gcloud artifacts docker tags list \
    us-central1-docker.pkg.dev/$project_id/rstudio-repository/rstudio \
    --format="value(tag)" | grep -x "rc1" || true
)

if [[ -n "$TAG_EXISTS" ]]; then
    echo "NOTE: RStudio image/tag exists, skipping docker build."
else
  cd rstudio
  docker build \
       --build-arg RSTUDIO_PASSWORD="${RSTUDIO_PASSWORD}" \
       -t $GCR_IMAGE . 
  docker push $GCR_IMAGE
  cd ..
fi

cd ..

# ------------------------------------------------------------------------------------------
# Phase 4: GKE Cluster Deployment
# ------------------------------------------------------------------------------------------

cd 04-gke

terraform init
terraform apply \
  -auto-approve

cd .. # Return to project root


# ------------------------------------------------------------------------------------------
# Phase 5: Validation
# - Runs post-deployment validation checks to confirm successful setup
# ------------------------------------------------------------------------------------------
./validate.sh
