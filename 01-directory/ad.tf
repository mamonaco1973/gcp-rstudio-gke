# ==========================================================================================
# Mini Active Directory (mini-ad) Module Invocation
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Calls the reusable "mini-ad" module to provision an Ubuntu-based AD Domain Controller
#   - Passes in networking, DNS, and authentication parameters
#   - Supplies user account definitions via a JSON blob generated from a template
# ==========================================================================================

module "mini_ad" {
  source            = "github.com/mamonaco1973/module-gcp-mini-ad" # Path to the mini-ad Terraform module
  netbios           = var.netbios                                  # NetBIOS domain name (e.g., MCLOUD)
  network           = google_compute_network.gke_vpc.id            # VPC where the AD will reside
  realm             = var.realm                                    # Kerberos realm (usually UPPERCASE DNS domain)
  users_json        = local.users_json                             # JSON blob of users and passwords (built below)
  user_base_dn      = var.user_base_dn                             # Base DN for user accounts in LDAP
  ad_admin_password = random_password.admin_password.result        # Randomized AD administrator password
  dns_zone          = var.dns_zone                                 # DNS zone (e.g., mcloud.mikecloud.com)
  subnetwork        = google_compute_subnetwork.ad_subnet.id       # Subnet for AD VM placement
  email             = local.service_account_email                  # Service account email
  machine_type      = var.machine_type                             # Machine type for AD VM

  # Ensure NAT + route association exist before bootstrapping (for package repos, etc.)
  depends_on = [google_compute_subnetwork.ad_subnet,
    google_compute_router.ad_router,
  google_compute_router_nat.ad_nat]
}

# ==========================================================================================
# Local Variable: users_json
# ------------------------------------------------------------------------------------------
# - Renders a JSON file (`users.json.template`) into a single JSON blob
# - Injects unique random passwords for test/demo users
# - Template variables are replaced with real values at runtime
# - Passed into the VM bootstrap so users are created automatically
# ==========================================================================================

locals {
  users_json = templatefile("./scripts/users.json.template", {
    USER_BASE_DN    = var.user_base_dn                       # Base DN for placing new users in LDAP
    DNS_ZONE        = var.dns_zone                           # AD-integrated DNS zone
    REALM           = var.realm                              # Kerberos realm (FQDN in uppercase)
    NETBIOS         = var.netbios                            # NetBIOS domain name
    jsmith_password = random_password.jsmith_password.result # Random password for John Smith
    edavis_password = random_password.edavis_password.result # Random password for Emily Davis
    rpatel_password = random_password.rpatel_password.result # Random password for Raj Patel
    akumar_password = random_password.akumar_password.result # Random password for Amit Kumar
  })
}
