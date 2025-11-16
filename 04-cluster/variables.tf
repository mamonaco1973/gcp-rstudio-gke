############################################
# INPUT VARIABLES: NETWORK RESOURCES
############################################

# Defines a string input variable for the name of the existing VPC
# Allows flexibility across environments by avoiding hardcoded VPC names
variable "vpc_name" {
  description = "Name of the existing VPC network" # Describes the purpose of this input (critical for modular deployments)
  type        = string                             # Ensures only string values are accepted
  default     = "ad-vpc"
}

# Defines a string input variable for the name of the existing subnet
# Enables reusability of the module in any region or VPC structure
variable "subnet_name" {
  description = "Name of the existing subnetwork" # Clear description for input validation and documentation
  type        = string                            # Must be a valid string representing the subnet name
  default     = "ad-subnet"
}

############################################
# INPUT VARIABLES: PACKER IMAGE NAMES
############################################


variable "rstudio_image_name" {
  description = "Name of the Packer built rstudio image" # Explicitly describes the image being referenced
  type        = string                                   # Must be a string; typically something like "rstudio-ubuntu-20240418"
}

# Data source to lookup the actual image object in GCP based on the name and project
# Ensures that Terraform can retrieve the image metadata and use it for VM boot disks
data "google_compute_image" "rstudio_packer_image" {
  name    = var.rstudio_image_name       # Dynamically reference the image name provided by the variable
  project = local.credentials.project_id # Use the project ID from the decoded credentials (avoids hardcoding)
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

