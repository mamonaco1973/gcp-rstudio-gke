# ==============================================================================
# HELM PROVIDER AND NGINX INGRESS DEPLOYMENT
# ==============================================================================
# Configures the Helm provider to communicate with the GKE API server and
# deploys the NGINX Ingress Controller into the cluster using a Helm chart.
#
# Key Points:
#   - Uses google_client_config for OAuth token authentication.
#   - Connects to the GKE endpoint using the cluster CA certificate.
#   - Creates the ingress-nginx namespace automatically.
#   - Deploys NGINX with settings to enable a public external load balancer.
# ==============================================================================
data "google_client_config" "default" {}

provider "helm" {
  # ----------------------------------------------------------------------------
  # Kubernetes API Connection
  # ----------------------------------------------------------------------------
  # - Host: GKE control plane endpoint.
  # - Token: OAuth token for API authentication.
  # - CA Cert: Decoded certificate for TLS server validation.
  kubernetes = {
    host = "https://${google_container_cluster.primary.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    )
  }
}

# ==============================================================================
# HELM RELEASE: NGINX INGRESS CONTROLLER
# ==============================================================================
# Installs the ingress-nginx Helm chart into the cluster. Publishes the
# controller service externally by enabling publishService and setting the GCP
# load balancer type annotation.
#
# Key Points:
#   - Creates the ingress-nginx namespace automatically.
#   - Enables an external HTTPS load balancer on GCP.
#   - Required for exposing RStudio or any HTTP-based workloads.
# ==============================================================================
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = "ingress-nginx"
  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"

  create_namespace = true

  values = [
    <<EOF
controller:
  publishService:
    enabled: true
  service:
    annotations:
      cloud.google.com/load-balancer-type: "External"
EOF
  ]
}
