# ================================================================================================
# Google Cloud Filestore (Basic NFS Server) with Firewall Rules
# ================================================================================================
# Provisions a Filestore instance for NFS storage and secures access via a firewall rule.
#
# Key Points:
#   - Filestore provides fully managed NFS storage in GCP.
#   - Minimum size = 1 TB (1024 GiB).
#   - Instance is deployed in a specific zone (not region-wide).
#   - Basic tiers (HDD or SSD) support only NFSv3.
#   - NFS access allowed on port 2049 (TCP + UDP).
#   - Source range is open to 0.0.0.0/0 for lab use; restrict in production.
# ================================================================================================
resource "google_filestore_instance" "nfs_server" {

  # ----------------------------------------------------------------------------------------------
  # Filestore Configuration
  # ----------------------------------------------------------------------------------------------
  # - Name must be unique within the project.
  # - Tier determines performance and pricing. Options:
  #     BASIC_HDD, BASIC_SSD  (NFSv3 only)
  #     HIGH_SCALE_SSD, ENTERPRISE (NFSv3 + NFSv4.1)
  # - Location must be a zone (e.g., us-central1-b), not just a region.
  # - Project ID is pulled from local credentials.
  name     = "nfs-server"
  tier     = "BASIC_HDD"     # Reverted to Basic HDD
  location = "us-central1-b" # Zonal, not regional
  project  = local.credentials.project_id

  # ----------------------------------------------------------------------------------------------
  # File Share Configuration
  # ----------------------------------------------------------------------------------------------
  # - Minimum capacity for Basic Filestore is 1 TB (1024 GiB).
  # - Export options define client access mode, root squash, and allowed IP ranges.
  file_shares {
    capacity_gb = 1024 # 1 TB minimum
    name        = "filestore"

    nfs_export_options {
      access_mode = "READ_WRITE"     # Allow read/write access
      squash_mode = "NO_ROOT_SQUASH" # Preserve root privileges on clients
      ip_ranges   = ["0.0.0.0/0"]    # ⚠️ Lab only; restrict in production
    }
  }

  # ----------------------------------------------------------------------------------------------
  # Network Configuration
  # ----------------------------------------------------------------------------------------------
  # - Attaches Filestore to the specified VPC network.
  # - Modes set to IPv4 only (default for most labs).
  networks {
    network = data.google_compute_network.ad_vpc.name
    modes   = ["MODE_IPV4"]
  }
}

# ================================================================================================
# Firewall Rule: Allow NFS Traffic
# ================================================================================================
# Grants network access to NFS port (2049) over both TCP and UDP.
#
# Key Points:
#   - Required for Linux clients to mount Filestore over NFS.
#   - Source range is wide open (0.0.0.0/0) for lab use.
#   - In production, restrict to specific subnets or client ranges.
# ================================================================================================
resource "google_compute_firewall" "allow_nfs" {
  name    = "allow-nfs"
  network = data.google_compute_network.ad_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  allow {
    protocol = "udp"
    ports    = ["2049"]
  }

  source_ranges = ["0.0.0.0/0"] # ⚠️ Lab only; tighten to your subnet CIDR in production
}

# ================================================================================================
# Output: Filestore IP Address
# ================================================================================================
# Exposes the Filestore instance’s private IP address for use in mount commands.
# Example mount path: <IP_ADDRESS>:/filestore
# ================================================================================================
# output "filestore_ip" {
#   value = google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
# }
