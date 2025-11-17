#!/bin/bash
# ==============================================================================
# Destroy Pipeline Script: Mini-AD + RStudio on GCP (GKE version)
# ------------------------------------------------------------------------------
# Purpose:
#   - Removes all deployed components in reverse build order
#   - Deletes GKE workloads, servers, and Mini-AD resources
#   - Ensures no leftover GCP resources remain after teardown
# ==============================================================================

set -e  # Exit immediately if any command returns a non-zero status

# ------------------------------------------------------------------------------
# Phase 1: Remove RStudio GKE Workloads
# - Deletes Kubernetes deployments, services, and config
# ------------------------------------------------------------------------------

kubectl delete -f rstudio-app.yaml || true

# ------------------------------------------------------------------------------
# Phase 2: Destroy GKE Cluster
# - Removes the Kubernetes cluster and supporting components
# ------------------------------------------------------------------------------

cd 04-gke

terraform init
terraform destroy -auto-approve

cd ..  # Return to project root

# ------------------------------------------------------------------------------
# Phase 3: Server Teardown
# - Destroys Windows and Linux hosts joined to Mini-AD
# ------------------------------------------------------------------------------

cd 02-servers

terraform init
terraform destroy -auto-approve

cd ..  # Return to project root

# ------------------------------------------------------------------------------
# Phase 4: Active Directory Teardown
# - Removes the Samba-based Mini-AD infrastructure
# ------------------------------------------------------------------------------

cd 01-directory

terraform init
terraform destroy -auto-approve

cd ..  # Return to project root
