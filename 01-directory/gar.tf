# ==============================================================================
# Google Artifact Registry Repository - RStudio Container Repository
# ==============================================================================
# PURPOSE:
#   - Create a Docker-format repository in Google Artifact Registry.
#   - Stores RStudio Server container images used by GKE workloads.
#   - Must be deployed in the same region as the GKE cluster to avoid latency.
# ==============================================================================

resource "google_artifact_registry_repository" "rstudio_repo" {

  # ----------------------------------------------------------------------------
  # Provider and Project Context
  # ----------------------------------------------------------------------------
  provider      = google                       # Authenticated Google provider
  project       = local.credentials.project_id # GCP project ID from credentials

  # ----------------------------------------------------------------------------
  # Repository Configuration
  # ----------------------------------------------------------------------------
  location      = "us-central1"                # Region; match your GKE cluster
  repository_id = "rstudio-repository"         # Logical repo name
  format        = "DOCKER"                     # Enable Docker image storage
}
