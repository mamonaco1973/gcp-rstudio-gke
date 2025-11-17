#!/bin/bash
# ==========================================================================================
# Destroy Pipeline Script: Mini-AD + RStudio Cluster on GCP
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Tears down deployed infrastructure in reverse order of build
#   - Removes RStudio cluster, custom images, servers, and Active Directory
#   - Ensures no residual GCP resources remain after cleanup
# ==========================================================================================

set -e  # Exit immediately on any unhandled command failure

kubectl delete -f rstudio-app.yaml || true

cd 04-gke

terraform init
terraform destroy -auto-approve

cd .. # Return to project root

# ------------------------------------------------------------------------------------------
# Phase 3: Server Teardown
# - Removes Windows and Linux client VMs connected to Active Directory
# ------------------------------------------------------------------------------------------

cd 02-servers

terraform init
terraform destroy -auto-approve

cd .. # Return to project root


# ------------------------------------------------------------------------------------------
# Phase 4: Active Directory Teardown
# - Destroys the Samba-based Active Directory resources
# ------------------------------------------------------------------------------------------

cd 01-directory

terraform init
terraform destroy -auto-approve

cd .. # Return to project root
