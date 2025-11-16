# ================================================================================================
# Active Directory User Credentials in GCP Secret Manager
# ================================================================================================
# Provisions:
#   1. Random passwords for each AD user.
#   2. Secret Manager entries for storing credentials.
#   3. IAM bindings granting the service account access to retrieve these secrets.
#
# Key Points:
#   - Users: Admin, John Smith, Emily Davis, Raj Patel, Amit Kumar.
#   - Random passwords include special characters, with controlled override sets.
#   - Secrets stored securely in GCP Secret Manager.
#   - Service account is granted `roles/secretmanager.secretAccessor` on all secrets.
# ================================================================================================


# ================================================================================================
# User: Admin
# ================================================================================================
# Generates password and stores AD credentials for the `RSTUDIO\admin` account.
# ================================================================================================
resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "_."
}

resource "google_secret_manager_secret" "admin_secret" {
  secret_id = "admin-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.admin_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\admin"
    password = random_password.admin_password.result
  })
}


# ================================================================================================
# User: John Smith
# ================================================================================================
# Generates password and stores AD credentials for the `RSTUDIO\jsmith` account.
# ================================================================================================
resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "jsmith_secret" {
  secret_id = "jsmith-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jsmith_secret_version" {
  secret = google_secret_manager_secret.jsmith_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\jsmith"
    password = random_password.jsmith_password.result
  })
}


# ================================================================================================
# User: Emily Davis
# ================================================================================================
# Generates password and stores AD credentials for the `RSTUDIO\edavis` account.
# ================================================================================================
resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "edavis_secret" {
  secret_id = "edavis-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "edavis_secret_version" {
  secret = google_secret_manager_secret.edavis_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\edavis"
    password = random_password.edavis_password.result
  })
}


# ================================================================================================
# User: Raj Patel
# ================================================================================================
# Generates password and stores AD credentials for the `RSTUDIO\rpatel` account.
# ================================================================================================
resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "rpatel_secret" {
  secret_id = "rpatel-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rpatel_secret_version" {
  secret = google_secret_manager_secret.rpatel_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\rpatel"
    password = random_password.rpatel_password.result
  })
}


# ================================================================================================
# User: Amit Kumar
# ================================================================================================
# Generates password and stores AD credentials for the `RSTUDIO\akumar` account.
# ================================================================================================
resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "akumar_secret" {
  secret_id = "akumar-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "akumar_secret_version" {
  secret = google_secret_manager_secret.akumar_secret.id
  secret_data = jsonencode({
    username = "RSTUDIO\\akumar"
    password = random_password.akumar_password.result
  })
}

# ================================================================================================
# User: rstudio local debug account
# ================================================================================================
# Generates password and store credentials for local rstudio debug account
# ================================================================================================
resource "random_password" "rstudio_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "google_secret_manager_secret" "rstudio_secret" {
  secret_id = "rstudio-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rstudio_secret_version" {
  secret = google_secret_manager_secret.rstudio_secret.id
  secret_data = jsonencode({
    username = "rstudio"
    password = random_password.rstudio_password.result
  })
}


# ================================================================================================
# Locals: Secret List
# ================================================================================================
# Collects all secret IDs into a single list for use with IAM bindings.
# ================================================================================================
locals {
  secrets = [
    google_secret_manager_secret.jsmith_secret.secret_id,
    google_secret_manager_secret.edavis_secret.secret_id,
    google_secret_manager_secret.rpatel_secret.secret_id,
    google_secret_manager_secret.akumar_secret.secret_id,
    google_secret_manager_secret.admin_secret.secret_id,
    google_secret_manager_secret.rstudio_secret.secret_id
  ]
}


# ================================================================================================
# IAM Binding: Grant Secret Access
# ================================================================================================
# Grants the service account `roles/secretmanager.secretAccessor` on each secret.
#
# Key Points:
#   - Iterates over the list of secrets using `for_each`.
#   - Service account must already exist.
#   - Enables VMs or automation to retrieve user credentials.
# ================================================================================================
resource "google_secret_manager_secret_iam_binding" "secret_access" {
  for_each  = toset(local.secrets)
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${local.service_account_email}"
  ]
}
