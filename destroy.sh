#!/bin/bash
# ==========================================================================================
# Destroy Pipeline Script: Mini-AD + RStudio Cluster on GCP
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Tears down deployed infrastructure in reverse order of build
#   - Removes RStudio cluster, custom images, servers, and Active Directory
#   - Ensures no residual GCP resources remain after cleanup
# ==========================================================================================

# ------------------------------------------------------------------------------------------
# Phase 1: RStudio Cluster Teardown
# - Destroys the RStudio cluster using the latest built image
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
terraform destroy \
  -var="rstudio_image_name=$rstudio_image" \
  -auto-approve

cd .. # Return to project root

# ------------------------------------------------------------------------------------------
# Phase 2: Custom Image Cleanup
# - Deletes Packer-built images with known prefixes (rstudio)
# ------------------------------------------------------------------------------------------

echo "NOTE: Fetching images starting with 'rstudio' to delete..."

image_list=$(gcloud compute images list \
  --format="value(name)" \
  --filter="name~'^(rstudio)'") # Regex match for prefix

if [ -z "$image_list" ]; then
  echo "NOTE: No images found starting with 'rstudio'. Nothing to delete."
else
  echo "NOTE: Deleting images..."
  for image in $image_list; do
    echo "NOTE: Deleting image: $image"
    gcloud compute images delete "$image" --quiet \
      || echo "WARNING: Failed to delete image: $image"
  done
fi

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
