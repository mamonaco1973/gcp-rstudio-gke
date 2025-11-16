# #!/bin/bash
# # ==========================================================================================
# # Validation Script: Retrieve Public IPs and Verify Load Balancer
# # ------------------------------------------------------------------------------------------
# # Purpose:
# #   - Fetches public IPs for key resources (NFS gateway, Windows AD instance,
# #     RStudio load balancer)
# #   - Validates that the load balancer is active and serving requests
# #   - Provides user-friendly status messages for troubleshooting
# # ==========================================================================================


# # ------------------------------------------------------------------------------------------
# # Step 1: Retrieve NFS Gateway Public IP
# # - Queries Compute Engine for instances with name starting "nfs-gateway"
# # - Extracts the NAT public IP assigned to the VM
# # ------------------------------------------------------------------------------------------

# NFS_IP=$(gcloud compute instances list \
#   --filter="name~'^nfs-gateway'" \
#   --format="value(networkInterfaces.accessConfigs[0].natIP)")

# echo "NOTE: Linux nfs-gateway public IP address is $NFS_IP"


# # ------------------------------------------------------------------------------------------
# # Step 2: Retrieve Windows AD Instance Public IP
# # - Queries for instance name starting with "win-ad"
# # - Extracts the NAT public IP assigned to the VM
# # ------------------------------------------------------------------------------------------

# WIN_IP=$(gcloud compute instances list \
#   --filter="name~'^win-ad'" \
#   --format="value(networkInterfaces.accessConfigs[0].natIP)")

# echo "NOTE: Windows instance public IP address is $WIN_IP"


# # ------------------------------------------------------------------------------------------
# # Step 3: Retrieve Load Balancer Public IP
# # - Gets the static global IP reserved for the RStudio load balancer
# # ------------------------------------------------------------------------------------------

# RSTUDIO_LB_IP=$(gcloud compute addresses describe rstudio-lb-ip \
#   --global \
#   --format="value(address)")

# if [ -z "$RSTUDIO_LB_IP" ]; then
#     echo "ERROR: Failed to retrieve the load balancer IP address. Exiting."
#     exit 1
# fi


# # ------------------------------------------------------------------------------------------
# # Step 4: Validate Load Balancer Availability
# # - Continuously poll the /auth-sign-in endpoint on the LB
# # - Exit once HTTP 200 is returned, otherwise wait and retry
# # ------------------------------------------------------------------------------------------

# URL="http://$RSTUDIO_LB_IP/auth-sign-in"

# while true; do
#   HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
  
#   if [ "$HTTP_CODE" -eq 200 ]; then
#      echo "NOTE: Load balancer is active. Access RStudio at http://$RSTUDIO_LB_IP"
#      exit 0
#   else
#     echo "WARNING: Waiting for the load balancer to become active."
#     sleep 60
#   fi
# done
