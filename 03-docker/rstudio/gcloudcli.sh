#!/bin/bash
set -euo pipefail

# Prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------------
# Install Google Cloud SDK (gcloud CLI)
# ---------------------------------------------------------------------------------

# Import Google Cloud apt repository key
curl -sSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | gpg --dearmor \
  | tee /usr/share/keyrings/google-cloud-sdk-archive-keyring.gpg >/dev/null

# Add the Google Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/google-cloud-sdk-archive-keyring.gpg] \
https://packages.cloud.google.com/apt cloud-sdk main" \
  | tee /etc/apt/sources.list.d/google-cloud-sdk.list

# Update package lists
apt-get update -y

# Install the Google Cloud SDK (gcloud CLI)
apt-get install -y google-cloud-cli >> /root/userdata.log 2>&1
