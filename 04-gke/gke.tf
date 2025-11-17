# ==============================================================================
# GKE CLUSTER: PRIMARY CONTROL PLANE CONFIGURATION
# ==============================================================================
# Provisions a GKE control plane with private nodes, Workload Identity, and
# VPC-native IP addressing.
#
# Key Points:
#   - Removes default node pool so a custom pool can be defined.
#   - Attaches to a custom VPC and subnet.
#   - Enables Workload Identity for pod-level GCP access.
#   - Private nodes prevent assignment of public IP addresses.
#   - Alias IP ranges used via VPC-native mode.
# ==============================================================================
resource "google_container_cluster" "primary" {

  # ----------------------------------------------------------------------------
  # Cluster Identity and Location
  # ----------------------------------------------------------------------------
  # - Cluster name derived from input variable.
  # - Location must be a zone for a zonal cluster.
  name     = var.gke_cluster_name
  location = var.zone

  # ----------------------------------------------------------------------------
  # Default Node Pool Removal
  # ----------------------------------------------------------------------------
  # - Removes default pool so cluster can be managed cleanly.
  remove_default_node_pool = true
  initial_node_count       = 1

  # ----------------------------------------------------------------------------
  # Cluster Networking
  # ----------------------------------------------------------------------------
  # - Attaches to custom VPC and subnet.
  # - Enables alias IP ranges via ip_allocation_policy.
  network    = data.google_compute_network.gke_vpc.name
  subnetwork = data.google_compute_subnetwork.ad_subnet.name

  ip_allocation_policy {}

  # ----------------------------------------------------------------------------
  # Cluster Deletion Controls
  # ----------------------------------------------------------------------------
  # - Allows terraform destroy without locking.
  deletion_protection = false

  # ----------------------------------------------------------------------------
  # Workload Identity Configuration
  # ----------------------------------------------------------------------------
  # - Maps Kubernetes SA identities to Google SA identities.
  workload_identity_config {
    workload_pool = "${local.credentials.project_id}.svc.id.goog"
  }

  # ----------------------------------------------------------------------------
  # Private Node Configuration
  # ----------------------------------------------------------------------------
  # - Node VMs do not receive public IPs.
  private_cluster_config {
    enable_private_nodes = true
  }
}

# ==============================================================================
# GKE NODE POOL: COMPUTE WORKERS FOR RSTUDIO WORKLOADS
# ==============================================================================
# Defines a custom node pool using e2-standard-4 machines and autoscaling to
# support dynamic RStudio sessions.
#
# Key Points:
#   - Autoscaling adjusts node count from 1 to 4.
#   - OAuth scopes allow logging and monitoring access.
#   - Attaches directly to the primary cluster.
# ==============================================================================
resource "google_container_node_pool" "primary_nodes" {

  # ----------------------------------------------------------------------------
  # Node Pool Identity and Cluster Binding
  # ----------------------------------------------------------------------------
  name     = "default-node-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  # ----------------------------------------------------------------------------
  # Node Compute Configuration
  # ----------------------------------------------------------------------------
  # - Machine type provides balanced compute for workloads.
  # - OAuth scopes allow GCP agents to run correctly.
  node_config {
    machine_type = "e2-standard-4"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # ----------------------------------------------------------------------------
  # Autoscaling Configuration
  # ----------------------------------------------------------------------------
  # - Defines min and max node counts for workload bursts.
  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }

  # ----------------------------------------------------------------------------
  # Initial Node Count
  # ----------------------------------------------------------------------------
  initial_node_count = 1
}

# ==============================================================================
# KUBERNETES PROVIDER CONFIGURATION
# ==============================================================================
# Connects Terraform to the GKE Kubernetes API server using OAuth token-based
# authentication and the cluster's CA certificate.
#
# Key Points:
#   - Uses google_client_config to retrieve access token.
#   - Decodes cluster CA certificate for TLS validation.
#   - Required for Terraform-managed Kubernetes resources.
# ==============================================================================
provider "kubernetes" {

  # ----------------------------------------------------------------------------
  # API Server Connection Details
  # ----------------------------------------------------------------------------
  host  = "https://${google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token

  cluster_ca_certificate = base64decode(
    google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

# ==============================================================================
# GOOGLE SERVICE ACCOUNT: RSTUDIO GSA
# ==============================================================================
# Creates a Google service account used by RStudio pods for access to Secret
# Manager and GAR via Workload Identity.
#
# Key Points:
#   - Bound to Kubernetes SA rstudio-sa for WI.
#   - Least-privilege access applied via IAM roles.
# ==============================================================================
resource "google_service_account" "rstudio_gsa" {

  # ----------------------------------------------------------------------------
  # Service Account Identity
  # ----------------------------------------------------------------------------
  account_id   = "rstudio-rw"
  display_name = "RStudio GSA for reading secrets"
}

# ==============================================================================
# KUBERNETES SERVICE ACCOUNT: RSTUDIO KSA
# ==============================================================================
# Creates a Kubernetes service account used by RStudio pods. Annotated to bind
# the KSA to the GSA for Workload Identity impersonation.
#
# Key Points:
#   - Namespace: default.
#   - Annotation maps to rstudio_gsa GSA.
# ==============================================================================
resource "kubernetes_service_account" "rstudio_ksa" {

  metadata {
    name      = "rstudio-sa"
    namespace = "default"

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.rstudio_gsa.email
    }
  }
}

# ==============================================================================
# WORKLOAD IDENTITY BINDING: KSA IMPERSONATION OF GSA
# ==============================================================================
# Grants the Kubernetes SA permission to impersonate the Google SA for secure
# API access using Workload Identity.
#
# Key Points:
#   - Required role: iam.workloadIdentityUser.
#   - Fully qualified member string required.
# ==============================================================================
resource "google_service_account_iam_member" "wi_binding" {

  service_account_id = google_service_account.rstudio_gsa.name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${local.credentials.project_id}.svc.id.goog[default/rstudio-sa]"

}

# ==============================================================================
# PROJECT IAM: SECRET MANAGER ACCESS FOR RSTUDIO GSA
# ==============================================================================
# Grants the Google service account permission to read secrets stored in Secret
# Manager. Used by domain-join scripts and pod initialization routines.
#
# Key Points:
#   - Uses secretAccessor role.
#   - Applied at project level.
# ==============================================================================
resource "google_project_iam_member" "secret_access" {

  project = local.credentials.project_id
  role    = "roles/secretmanager.secretAccessor"

  member = "serviceAccount:${google_service_account.rstudio_gsa.email}"
}
