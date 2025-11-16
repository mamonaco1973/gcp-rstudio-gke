# ==========================================================================================
# Google Cloud Provider Configuration
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Configures Terraform to interact with Google Cloud
#   - Authenticates using a local service account credentials file
#   - Ensures resources are provisioned in the correct GCP project
# ==========================================================================================
provider "google" {
  project     = local.credentials.project_id
  credentials = file("../credentials.json")
}


# ==========================================================================================
# Local Variables: Credentials Parsing
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Parses the service account JSON credentials file
#   - Extracts fields for use across resources (e.g., project ID, email)
# ==========================================================================================
locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}


# ==========================================================================================
# Data Sources: Existing Network Infrastructure
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Looks up existing VPC and subnet by name
#   - Ensures new resources integrate with predefined networking
# ==========================================================================================
data "google_compute_network" "ad_vpc" {
  name = var.vpc_name
}

data "google_compute_subnetwork" "ad_subnet" {
  name   = var.subnet_name
  region = "us-central1"
}


# ==========================================================================================
# Data Source: Existing Filestore Instance
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Retrieves details of an existing Filestore NFS server
#   - Enables references in VM startup scripts or mounts
# ==========================================================================================
data "google_filestore_instance" "nfs_server" {
  name     = "nfs-server"
  location = "us-central1-b"
  project  = local.credentials.project_id
}
