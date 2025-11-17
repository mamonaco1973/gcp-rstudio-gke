# ================================================================================================
# Google Cloud Provider & Local Variables
# ================================================================================================
# Configures the Google Cloud provider for Terraform, using credentials from a JSON file.
#
# Key Points:
#   - Provider uses project ID and credentials for authentication.
#   - Local variables decode the JSON credentials for reuse (project_id, service account email).
# ================================================================================================
provider "google" {
  project     = local.credentials.project_id # Project ID extracted from credentials.json
  credentials = file("../credentials.json")  # Path to service account credentials file
}

# ================================================================================================
# Local Variables
# ================================================================================================
# Decodes the credentials JSON file and extracts useful fields.
#
# Key Points:
#   - `credentials` local contains the entire decoded JSON map.
#   - `service_account_email` provides the service account identity for resource bindings.
# ================================================================================================
locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}


# ================================================================================================
# Data Sources: Network and Subnet
# ================================================================================================
# Looks up existing VPC network and subnet for resource attachment.
#
# Key Points:
#   - `gke-vpc` is the base VPC for Active Directory lab resources.
#   - `ad-subnet` defines the subnet within `us-central1`.
# ================================================================================================
data "google_compute_network" "gke_vpc" {
  name = "gke-vpc"
}

data "google_compute_subnetwork" "ad_subnet" {
  name   = "ad-subnet"
  region = "us-central1"
}
