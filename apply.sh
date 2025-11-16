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
# Phase 3: RStudio Image Build
# - Builds a custom Compute Engine image with RStudio using Packer
# ------------------------------------------------------------------------------------------

project_id=$(jq -r '.project_id' "./credentials.json")

# Authenticate with service account from credentials file
gcloud auth activate-service-account \
  --key-file="./credentials.json" > /dev/null 2> /dev/null

# Export path for Google credentials (used by Packer)
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

cd 03-packer
packer build \
  -var="project_id=$project_id" \
  rstudio_image.pkr.hcl
cd .. # Return to project root


# ------------------------------------------------------------------------------------------
# Phase 4: RStudio Cluster Deployment
# - Provisions auto-scaling cluster of RStudio servers from Phase 3 image
# ------------------------------------------------------------------------------------------

rstudio_image=$(gcloud compute images list \
  --filter="name~'^rstudio-image' AND family=rstudio-images" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)")

if [[ -z "$rstudio_image" ]]; then
  echo "ERROR: No latest image found for 'rstudio-image' in family 'rstudio-images'."
  exit 1
fi

cd 04-cluster

terraform init
terraform apply \
  -var="rstudio_image_name=$rstudio_image" \
  -auto-approve

cd .. # Return to project root


# ------------------------------------------------------------------------------------------
# Phase 5: Validation
# - Runs post-deployment validation checks to confirm successful setup
# ------------------------------------------------------------------------------------------
./validate.sh
