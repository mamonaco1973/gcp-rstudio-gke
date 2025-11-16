# ================================================================================================
# SysAdmin Credentials + Windows AD Management VM with RDP Firewall
# ================================================================================================
# Provisions:
#   1. SysAdmin password (randomly generated, stored securely in GCP Secret Manager).
#   2. Firewall rule allowing inbound RDP (port 3389) access to tagged Windows instances.
#   3. Windows Server 2022 instance for Active Directory administration.
#   4. Data source to fetch the latest Windows Server 2022 image.
#
# Key Points:
#   - SysAdmin credentials are securely managed in Secret Manager.
#   - Firewall rules are tag-based in GCP (unlike AWS Security Groups).
#   - RDP rule is wide open (0.0.0.0/0) — ⚠️ insecure in production.
#   - Windows VM auto-joins the AD domain using a startup PowerShell script.
# ================================================================================================


# ================================================================================================
# SysAdmin Credentials
# ================================================================================================
# Generates a secure random password for the SysAdmin account and stores it in
# GCP Secret Manager for retrieval by automation or administrators.
# ================================================================================================
resource "random_password" "sysadmin_password" {
  length           = 24
  special          = true
  override_special = "-_."
}

resource "google_secret_manager_secret" "sysadmin_secret" {
  secret_id = "sysadmin-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.sysadmin_secret.id
  secret_data = jsonencode({
    username = "sysadmin"
    password = random_password.sysadmin_password.result
  })
}


# ================================================================================================
# Firewall Rule: Allow RDP
# ================================================================================================
# Grants inbound RDP access (port 3389) to Windows VMs tagged with "allow-rdp".
#
# Key Points:
#   - RDP requires TCP port 3389.
#   - Rule applies only to instances with `allow-rdp` tag.
#   - Source range is open to the internet (0.0.0.0/0) — ⚠️ dangerous in production.
# ================================================================================================
resource "google_compute_firewall" "allow_rdp" {
  name    = "allow-rdp"
  network = "ad-vpc"

  # Allow TCP traffic on port 3389 (RDP)
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  # Restrict rule application to instances with this tag
  target_tags = ["allow-rdp"]

  # ⚠️ Lab only; restrict source ranges for production
  source_ranges = ["0.0.0.0/0"]
}


# ================================================================================================
# Windows AD Management VM
# ================================================================================================
# Provisions a Windows Server 2022 VM for Active Directory administration and domain join tasks.
#
# Key Points:
#   - Uses latest Windows Server 2022 image from GCP.
#   - VM tagged with "allow-rdp" so the firewall rule applies.
#   - Startup script auto-joins the VM to the AD domain.
#   - Admin credentials passed from Terraform into metadata.
# ================================================================================================
resource "google_compute_instance" "windows_ad_instance" {
  name         = "win-ad-${random_string.vm_suffix.result}" # Random suffix for uniqueness
  machine_type = "e2-standard-2"                            # Balanced instance size for Windows
  zone         = "us-central1-a"

  # ----------------------------------------------------------------------------------------------
  # Boot Disk (Windows Server 2022)
  # ----------------------------------------------------------------------------------------------
  boot_disk {
    initialize_params {
      image = data.google_compute_image.windows_2022.self_link
    }
  }

  # ----------------------------------------------------------------------------------------------
  # Network Interface
  # ----------------------------------------------------------------------------------------------
  network_interface {
    network    = "ad-vpc"
    subnetwork = "ad-subnet"

    # Assigns a public IP so RDP connections can reach the VM
    access_config {}
  }

  # ----------------------------------------------------------------------------------------------
  # Service Account
  # ----------------------------------------------------------------------------------------------
  # Grants VM access to GCP APIs, useful for AD join automation or secret retrieval.
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------------------------
  # Startup Script (Domain Join)
  # ----------------------------------------------------------------------------------------------
  # Automatically runs at first boot to join the Windows VM to the AD domain.
  metadata = {
    windows-startup-script-ps1 = templatefile("./scripts/ad_join.ps1", {
      domain_fqdn = "rstudio.mikecloud.com"
      nfs_gateway = google_compute_instance.nfs_gateway_instance.network_interface[0].network_ip
    })

    admin_username = "sysadmin"
    admin_password = random_password.sysadmin_password.result
  }

  # ----------------------------------------------------------------------------------------------
  # Firewall Tags
  # ----------------------------------------------------------------------------------------------
  # Applies the "allow-rdp" firewall rule to this VM.
  tags = ["allow-rdp"]
}


# ================================================================================================
# Data Source: Latest Windows Server 2022 Image
# ================================================================================================
# Dynamically fetches the latest Windows Server 2022 image from the official
# `windows-cloud` project, ensuring deployments always use a patched OS image.
# ================================================================================================
data "google_compute_image" "windows_2022" {
  family  = "windows-2022"
  project = "windows-cloud"
}
