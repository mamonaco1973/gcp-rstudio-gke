#!/bin/bash
# ==============================================================================
# Validation Script: GKE RStudio Deployment Health Check
# ------------------------------------------------------------------------------
# Purpose:
#   - Retrieves public IPs for helper VMs and GKE ingress service
#   - Waits for the RStudio ingress IP to be assigned by GKE
#   - Verifies that the RStudio endpoint returns an HTTP 200 response
# ==============================================================================

# ------------------------------------------------------------------------------
# Step 1: Retrieve NFS Gateway Public IP
# - Queries Compute Engine for VMs named like "nfs-gateway"
# - Extracts their external NAT IP address
# ------------------------------------------------------------------------------

NFS_IP=$(gcloud compute instances list \
  --filter="name~'^nfs-gateway'" \
  --format="value(networkInterfaces.accessConfigs[0].natIP)")

echo "NOTE: Linux nfs-gateway public IP address: $NFS_IP"

# ------------------------------------------------------------------------------
# Step 2: Retrieve Windows AD Instance Public IP
# - Queries Compute Engine for VMs named like "win-ad"
# - Extracts the external NAT IP used for admin or debugging
# ------------------------------------------------------------------------------

WIN_IP=$(gcloud compute instances list \
  --filter="name~'^win-ad'" \
  --format="value(networkInterfaces.accessConfigs[0].natIP)")

echo "NOTE: Windows AD instance public IP address: $WIN_IP"

# ------------------------------------------------------------------------------
# Step 3: Wait for GKE Ingress External IP
# - Monitors the GKE ingress object "rstudio-ingress"
# - Waits until the Kubernetes LB controller assigns an IP
# ------------------------------------------------------------------------------

MAX_WAIT=300        # Max wait time (seconds)
SLEEP_INTERVAL=5    # Interval between checks
ELAPSED=0

echo "NOTE: Waiting for GKE ingress 'rstudio-ingress' external IP..."

while true; do
  RSTUDIO_LB_IP=$(
    kubectl get ingress rstudio-ingress \
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null
  )

  if [[ -n "$RSTUDIO_LB_IP" ]]; then
    echo "NOTE: Ingress external IP assigned: $RSTUDIO_LB_IP"
    break
  fi

  if (( ELAPSED >= MAX_WAIT )); then
    echo "ERROR: Timed out waiting for ingress external IP." >&2
    exit 1
  fi

  echo "NOTE: Ingress IP not available. Retrying..."
  sleep "$SLEEP_INTERVAL"
  (( ELAPSED += SLEEP_INTERVAL ))
done

# ------------------------------------------------------------------------------
# Step 4: Validate Load Balancer Availability
# - Polls the RStudio sign-in endpoint via ingress IP
# - Continues until HTTP 200 is returned
# ------------------------------------------------------------------------------

URL="http://$RSTUDIO_LB_IP/auth-sign-in"

while true; do
  HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")

  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "NOTE: RStudio service is active at: http://$RSTUDIO_LB_IP"
    exit 0
  fi

  echo "WARNING: Waiting for the RStudio endpoint to become active..."
  sleep 60
done
