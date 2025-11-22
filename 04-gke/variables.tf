############################################
# INPUT VARIABLES: NETWORK RESOURCES
############################################

# Defines a string input variable for the name of the existing VPC
# Allows flexibility across environments by avoiding hardcoded VPC names
variable "vpc_name" {
  description = "Name of the existing VPC network" # Describes the purpose of this input (critical for modular deployments)
  type        = string                             # Ensures only string values are accepted
  default     = "gke-vpc"
}

# Defines a string input variable for the name of the existing subnet
# Enables reusability of the module in any region or VPC structure
variable "subnet_name" {
  description = "Name of the existing subnetwork" # Clear description for input validation and documentation
  type        = string                            # Must be a valid string representing the subnet name
  default     = "ad-subnet"
}

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

# ====================================================================
# GCP REGION CONFIGURATION
# Must match where you provision other GCP services like subnets and GKE
# ====================================================================
variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

# ====================================================================
# GCP ZONE CONFIGURATION
# More specific than region — controls where GKE nodes live
# ====================================================================
variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

# ====================================================================
# GKE CLUSTER NAME
# This shows up in the GCP Console and influences node names, URLs, etc.
# Keep it short, lowercase, and unique in the region
# ====================================================================
variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "rstudio-gke"
}