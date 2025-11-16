# ==========================================================================================
# Static Global IP Address
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Reserves a global static IP address for the HTTP load balancer
#   - Ensures IP remains consistent even after LB updates or recreation
# ==========================================================================================
resource "google_compute_global_address" "lb_ip" {
  name = "rstudio-lb-ip"
}


# ==========================================================================================
# Backend Service
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Manages traffic distribution to the RStudio instance group
#   - Uses health checks to verify backends before routing traffic
# ==========================================================================================
resource "google_compute_backend_service" "backend_service" {
  name          = "rstudio-backend-service"
  protocol      = "HTTP"
  port_name     = "http" # Must match named port in MIG
  health_checks = [google_compute_health_check.http_health_check.self_link]

  timeout_sec           = 10
  load_balancing_scheme = "EXTERNAL"

  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 86400 # 1 day

  backend {
    group          = google_compute_region_instance_group_manager.instance_group_manager.instance_group
    balancing_mode = "UTILIZATION" # Balance traffic by utilization
  }

   depends_on = [time_sleep.wait_for_healthcheck]
}

resource "time_sleep" "wait_for_healthcheck" {
  depends_on      = [google_compute_health_check.http_health_check]
  create_duration = "120s"
}


# ==========================================================================================
# URL Map
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Routes incoming HTTP requests to the backend service
#   - Default rule sends all traffic to RStudio backend
# ==========================================================================================
resource "google_compute_url_map" "url_map" {
  name            = "rstudio-alb"
  default_service = google_compute_backend_service.backend_service.self_link
}


# ==========================================================================================
# Target HTTP Proxy
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Creates HTTP proxy that directs traffic to the URL map
# ==========================================================================================
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "rstudio-http-proxy"
  url_map = google_compute_url_map.url_map.id
}


# ==========================================================================================
# Global Forwarding Rule
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Defines entry point for HTTP traffic on port 80
#   - Directs requests to HTTP proxy using static global IP
# ==========================================================================================
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "rstudio-http-forwarding-rule"
  ip_address = google_compute_global_address.lb_ip.address
  target     = google_compute_target_http_proxy.http_proxy.self_link

  port_range            = "80"       # Listen on port 80 (HTTP)
  load_balancing_scheme = "EXTERNAL" # External-facing LB
}
