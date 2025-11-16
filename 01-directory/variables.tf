# ==================================================================================================
# Active Directory naming inputs
# - dns_zone : FQDN for the AD DNS zone / domain (e.g., mcloud.mikecloud.com)
# - realm    : Kerberos realm (typically the DNS zone in UPPERCASE)
# - netbios  : Short (pre-Windows 2000) domain name used by legacy/NetBIOS-aware systems
# ==================================================================================================

# --------------------------------------------------------------------------------
# DNS zone / AD domain (FQDN)
# Used by Samba AD DC for DNS namespace and domain identity
# --------------------------------------------------------------------------------
variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., rstudio.mikecloud.com)"
  type        = string
  default     = "rstudio.mikecloud.com"
}

# --------------------------------------------------------------------------------
# Kerberos realm (UPPERCASE)
# Convention: match dns_zone but uppercase; required by Kerberos config
# --------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE, e.g., RSTUDIO.MIKECLOUD.COM)"
  type        = string
  default     = "RSTUDIO.MIKECLOUD.COM"
}

# --------------------------------------------------------------------------------
# NetBIOS short domain name
# Typically <= 15 characters, uppercase alphanumerics; used by legacy clients and some SMB flows
# --------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., RSTUDIO)"
  type        = string
  default     = "RSTUDIO"
}

# --------------------------------------------------------------------------------
# User base DN for LDAP
# --------------------------------------------------------------------------------

variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=rstudio,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=rstudio,DC=mikecloud,DC=com"
}

# --------------------------------------------------------------------------------
# Zone for deployment
# --------------------------------------------------------------------------------

variable "zone" {
  description = "GCP zone for deployment (e.g., us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

# --------------------------------------------------------------------------------
# Machine type for mini AD instance
# --------------------------------------------------------------------------------

variable "machine_type" {
  description = "Machine type for mini AD instance (minimum is e2-small)"
  type        = string
  default     = "e2-medium"
}

# --------------------------------------------------------------------------------
# Network for mini AD instance
# --------------------------------------------------------------------------------

variable "network" {
  description = "Network for mini AD instance (e.g., ad-vpc)"
  type        = string
  default     = "ad-vpc"
}

# --------------------------------------------------------------------------------
# Sub-network for mini AD instance
# --------------------------------------------------------------------------------

variable "subnetwork" {
  description = "Sub-network for mini AD instance (e.g., ad-subnet)"
  type        = string
  default     = "ad-subnet"
}
