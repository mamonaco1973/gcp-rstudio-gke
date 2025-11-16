# ==========================================================================================
# Packer Build: RStudio Custom Image on Ubuntu 24.04 (Noble) for Google Cloud
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Uses Packer to build a custom GCP Compute Engine image containing RStudio
#   - Starts from the official Canonical Ubuntu 24.04 LTS base image family
#   - Installs prerequisites (base packages, RStudio Server)
#   - Produces a tagged, timestamped image for Terraform or Compute Engine use
# ==========================================================================================

# ------------------------------------------------------------------------------------------
# Packer Plugin Configuration
# - Defines the Google Compute plugin required to interact with GCP
# ------------------------------------------------------------------------------------------
packer {
  required_plugins {
    googlecompute = {
      source   = "github.com/hashicorp/googlecompute"  # Official plugin
      version  = "~> 1.1.6"                            # Lock to version 1.1.x
    }
  }
}

# ------------------------------------------------------------------------------------------
# Local Variables
# - Generates a compact timestamp for unique image naming
# ------------------------------------------------------------------------------------------
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "") # Format: YYYYMMDDHHMMSS
}

# ------------------------------------------------------------------------------------------
# Variables: Build-Time Inputs
# - Credentials and resource placement for the resulting custom image
# ------------------------------------------------------------------------------------------
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone where the build VM will run"
  type        = string
  default     = "us-central1-a"
}

variable "source_image_family" {
  description = "Base image family (e.g., ubuntu-2404-lts-amd64)"
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

# ------------------------------------------------------------------------------------------
# Source Block: Google Compute Builder
# - Launches a temporary VM from the Canonical Ubuntu 24.04 family
# - Installs required software and configuration
# - Captures a reusable custom image with a timestamp-based name
# ------------------------------------------------------------------------------------------

source "googlecompute" "rstudio_build_image" {
  project_id            = var.project_id             # Target GCP project
  zone                  = var.zone                   # Build zone
  source_image_family   = var.source_image_family    # Base image family
  ssh_username          = "ubuntu"                   # Default SSH username
  machine_type          = "e2-standard-2"            # Build VM size

  # Output image
  image_name            = "rstudio-image-${local.timestamp}" # Unique image
  image_family          = "rstudio-images"                   # Logical family
  disk_size             = 20                                 # Root disk (GB)
}

# ------------------------------------------------------------------------------------------
# Build Block: Provisioning Scripts
# - Executes provisioning scripts inside the temporary VM
# - Each script installs specific components
# ------------------------------------------------------------------------------------------
build {
  sources = ["source.googlecompute.rstudio_build_image"]  

  # Install base packages and dependencies
  provisioner "shell" {
    script          = "./packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  # Install and configure RStudio Server
  provisioner "shell" {
    script          = "./rstudio.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
