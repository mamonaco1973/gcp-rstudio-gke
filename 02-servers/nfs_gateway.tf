# ================================================================================================
# Random String, Firewall (SSH), and Ubuntu VM for AD/NFS Gateway
# ================================================================================================
# Provisions:
#   1. Random string suffix for uniqueness across resource names.
#   2. Firewall rule allowing inbound SSH (port 22) to tagged VMs.
#   3. Ubuntu 24.04 Compute Engine VM configured as an NFS gateway and AD join client.
#   4. Data source for the latest Ubuntu 24.04 LTS image.
#
# Key Points:
#   - Random suffix prevents name collisions when deploying multiple environments.
#   - SSH rule is wide open (0.0.0.0/0) — ⚠️ insecure for production.
#   - VM auto-runs a startup script to join AD and mount NFS from Filestore.
#   - Uses service account for GCP API access.
# ================================================================================================


# ================================================================================================
# Random String Generator
# ================================================================================================
# Generates a 6-character lowercase suffix to ensure resource name uniqueness.
# ================================================================================================
resource "random_string" "vm_suffix" {
  length  = 6     # Number of characters in the generated string
  special = false # Excludes special characters (DNS-friendly)
  upper   = false # Lowercase only for consistency
}


# ================================================================================================
# Firewall Rule: Allow SSH
# ================================================================================================
# Opens TCP port 22 for SSH access to VMs tagged with "allow-ssh".
#
# Key Points:
#   - Applies only to instances with "allow-ssh" tag.
#   - Source range is open to the internet (0.0.0.0/0) — ⚠️ restrict in production.
# ================================================================================================
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "gke-vpc"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Tag-based targeting (applies only to instances with this tag)
  target_tags = ["allow-ssh"]

  # ⚠️ Lab only; tighten for production
  source_ranges = ["0.0.0.0/0"]
}

# ================================================================================================
# Firewall Rule: Allow SMB (Windows File Sharing)
# ================================================================================================
# Opens TCP port 445 for SMB access to VMs tagged with "allow-smb".
#
# Key Points:
#   - Applies only to instances with "allow-smb" tag.
#   - Source range is open to the internet (0.0.0.0/0) — ⚠️ restrict in production.
# ================================================================================================
resource "google_compute_firewall" "allow_smb" {
  name    = "allow-smb"
  network = "gke-vpc"

  allow {
    protocol = "tcp"
    ports    = ["445"]
  }

  # Tag-based targeting (applies only to instances with this tag)
  target_tags = ["allow-smb"]

  # ⚠️ Lab only; tighten for production
  source_ranges = ["0.0.0.0/0"]
}


# ================================================================================================
# Ubuntu VM: NFS Gateway + AD Join Client
# ================================================================================================
# Deploys an Ubuntu 24.04 VM that:
#   - Connects to the "gke-vpc" network and "ad-subnet".
#   - Runs a startup script to join the AD domain and mount NFS from Filestore.
#   - Uses OS Login for secure SSH access.
#
# Key Points:
#   - Ephemeral public IP assigned for SSH.
#   - Startup script injects domain FQDN and Filestore IP.
#   - Service account grants API access.
# ================================================================================================
resource "google_compute_instance" "nfs_gateway_instance" {
  name         = "nfs-gateway-${random_string.vm_suffix.result}"
  machine_type = "e2-standard-2" 
  zone         = "us-central1-a"

  # ----------------------------------------------------------------------------------------------
  # Boot Disk
  # ----------------------------------------------------------------------------------------------
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_latest.self_link
    }
  }

  # ----------------------------------------------------------------------------------------------
  # Network Interface
  # ----------------------------------------------------------------------------------------------
  network_interface {
    network    = "gke-vpc"
    subnetwork = "ad-subnet"

    # Ephemeral public IP (required for SSH access)
    access_config {}
  }

  # ----------------------------------------------------------------------------------------------
  # Metadata (Startup Script + Config)
  # ----------------------------------------------------------------------------------------------
  metadata = {
    enable-oslogin = "TRUE" # Enforce OS Login for secure SSH

    startup-script = templatefile("./scripts/nfs_gateway_init.sh", {
      domain_fqdn   = "rstudio.mikecloud.com"
      nfs_server_ip = google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
      domain_fqdn   = var.dns_zone
      netbios       = var.netbios
      force_group   = "rstudio-users"
      realm         = var.realm
    })
  }

  # ----------------------------------------------------------------------------------------------
  # Service Account
  # ----------------------------------------------------------------------------------------------
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------------------------
  # Firewall Tags
  # ----------------------------------------------------------------------------------------------
  # Applies both SSH and NFS firewall rules
  tags = ["allow-ssh", "allow-nfs", "allow-smb"]
}


# ================================================================================================
# Data Source: Latest Ubuntu 24.04 LTS Image
# ================================================================================================
# Dynamically fetches the most recent Ubuntu 24.04 LTS image.
# Ensures VMs always launch with a patched image.
# ================================================================================================
data "google_compute_image" "ubuntu_latest" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}
