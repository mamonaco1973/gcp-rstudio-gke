# ==========================================================================================
# Instance Template: RStudio VM
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Defines the template for RStudio VM instances
#   - Specifies machine type, disk, network, and service account
#   - Used by the managed instance group for consistent deployments
# ==========================================================================================
resource "google_compute_instance_template" "rstudio_template" {
  name         = "rstudio-template" # Template name
  machine_type = "e2-standard-2"    # VM size (2 vCPU, 8 GB RAM)

  # Tags used for firewall rules (e.g., SSH and RStudio web access)
  tags = ["allow-rstudio"]

  # ----------------------------------------------------------------------------------------
  # Disk Configuration
  # - Uses Packer-built custom image as the boot disk
  # ----------------------------------------------------------------------------------------
  disk {
    auto_delete  = true # Delete disk when instance is destroyed
    boot         = true # Mark as boot disk
    source_image = data.google_compute_image.rstudio_packer_image.self_link
  }

  # ----------------------------------------------------------------------------------------
  # Network Configuration
  # - Attaches instance to VPC and subnet
  # ----------------------------------------------------------------------------------------
  network_interface {
    network    = data.google_compute_network.ad_vpc.id
    subnetwork = data.google_compute_subnetwork.ad_subnet.id
  }

  # ----------------------------------------------------------------------------------------
  # Service Account
  # - Grants cloud platform access to the VM
  # ----------------------------------------------------------------------------------------
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------------------
  # Add startup script from templatefile
  # ----------------------------------------------------------------------------------------

  metadata_startup_script = templatefile("./scripts/rstudio_booter.sh", {
    nfs_server_ip = data.google_filestore_instance.nfs_server.networks[0].ip_addresses[0]
    domain_fqdn   = var.dns_zone
    force_group   = "rstudio-users"
  })
}


# ==========================================================================================
# Regional Managed Instance Group
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Manages multiple instances based on the template
#   - Ensures scaling and healing policies for high availability
# ==========================================================================================
resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name               = "rstudio-instance-group"
  base_instance_name = "rstudio"
  target_size        = 2
  region             = "us-central1"

  # Template for creating instances
  version {
    instance_template = google_compute_instance_template.rstudio_template.self_link
  }

  # Named port for load balancing and health checks
  named_port {
    name = "http"
    port = 8787
  }

  # Auto-healing policy based on health checks
  auto_healing_policies {
    health_check      = google_compute_health_check.http_health_check.self_link
    initial_delay_sec = 300
  }
}


# ==========================================================================================
# Regional Autoscaler
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Adjusts instance count in the managed group
#   - Scales based on CPU utilization
# ==========================================================================================
resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "rstudio-autoscaler"
  target = google_compute_region_instance_group_manager.instance_group_manager.self_link
  region = "us-central1"

  autoscaling_policy {
    max_replicas    = 4   # Upper bound
    min_replicas    = 2   # Lower bound
    cooldown_period = 300 # Wait between scale actions

    cpu_utilization {
      target = 0.6 # Trigger scale at 60% CPU
    }
  }
}


# ==========================================================================================
# Firewall Rule: Allow RStudio (Web + SSH)
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Opens TCP ports 8787 (RStudio), 22 (SSH), and 80 (HTTP)
#   - Applies only to instances tagged "allow-rstudio"
#   - Uses wide-open source range (0.0.0.0/0) for lab/demo use
#   - ⚠️ Must restrict in production environments
# ==========================================================================================
resource "google_compute_firewall" "allow_rstudio" {
  name    = "allow-rstudio"
  network = "ad-vpc"

  allow {
    protocol = "tcp"
    ports    = ["8787", "22", "80"]
  }

  target_tags   = ["allow-rstudio"] # Restrict to tagged instances
  source_ranges = ["0.0.0.0/0"]     # ⚠️ Open internet access (lab only)
}


# ==========================================================================================
# Health Check: RStudio Service
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Monitors instance health for the managed group
#   - Marks instances healthy/unhealthy based on HTTP responses
# ==========================================================================================
resource "google_compute_health_check" "http_health_check" {
  name                = "http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    request_path = "/auth-sign-in"
    port         = 8787
  }
}
