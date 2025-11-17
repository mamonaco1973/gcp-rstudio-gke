# ================================================================================================
# Custom VPC, Subnet, Router, and NAT for Active Directory Environment
# ================================================================================================
# Provisions:
#   1. Custom-mode VPC (no default subnets).
#   2. Explicit subnet for AD resources.
#   3. Cloud Router to manage dynamic routing.
#   4. Cloud NAT for outbound internet without public IPs.
#
# Key Points:
#   - Custom VPC avoids auto-created subnets (better control).
#   - Subnet explicitly defined in `us-central1` with CIDR block 10.1.0.0/24.
#   - Cloud Router enables advanced networking features (e.g., NAT, BGP).
#   - Cloud NAT provides secure outbound access for private VMs.
# ================================================================================================


# ================================================================================================
# VPC Network: Active Directory VPC
# ================================================================================================
# Creates a custom-mode VPC named `ad-vpc`.
#
# Key Points:
#   - Auto subnet creation disabled.
#   - All subnets must be manually defined.
# ================================================================================================
resource "google_compute_network" "gke_vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}


# ================================================================================================
# Subnet: Active Directory Subnet
# ================================================================================================
# Defines a subnet inside the `gke-vpc` network for AD resources.
#
# Key Points:
#   - Located in `us-central1` region.
#   - CIDR: 10.1.0.0/24 (non-overlapping, must be large enough for resources).
#   - Explicitly tied to the VPC above.
# ================================================================================================
resource "google_compute_subnetwork" "ad_subnet" {
  name          = "ad-subnet"
  region        = "us-central1"
  network       = google_compute_network.gke_vpc.id
  ip_cidr_range = "10.1.0.0/24"
}


# ================================================================================================
# Cloud Router
# ================================================================================================
# Creates a Cloud Router in the AD VPC.
#
# Key Points:
#   - Required for Cloud NAT.
#   - Handles dynamic route advertisement and BGP if configured.
# ================================================================================================
resource "google_compute_router" "ad_router" {
  name    = "ad-router"
  network = google_compute_network.gke_vpc.id
  region  = "us-central1"
}


# ================================================================================================
# Cloud NAT
# ================================================================================================
# Provides outbound internet access for private resources in the AD subnet.
#
# Key Points:
#   - No need for public IPs on instances.
#   - NAT IPs are allocated automatically.
#   - Logs all flows (ALL).
# ================================================================================================
resource "google_compute_router_nat" "ad_nat" {
  name   = "ad-nat"
  router = google_compute_router.ad_router.name
  region = google_compute_router.ad_router.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}
