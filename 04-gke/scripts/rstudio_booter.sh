#!/bin/bash

FLAG_FILE="/root/.rstudio_provisioned"

#--------------------------------------------------------------------
# Prevent infinite loop from happening.
#--------------------------------------------------------------------

if [ -f "$FLAG_FILE" ]; then
  echo "Provisioning already completed — skipping." >> /root/userdata.log 2>&1
  exit 0
fi

# ---------------------------------------------------------------------------------
# Section 1: Mount NFS file system
# ---------------------------------------------------------------------------------

mkdir -p /nfs                                        # Create root NFS mount point

# Append root filestore entry to fstab (NFSv3 with tuned I/O + reliability options)
echo "${nfs_server_ip}:/filestore /nfs nfs vers=3,rw,hard,noatime,rsize=65536,wsize=65536,timeo=600,_netdev 0 0" \
| sudo tee -a /etc/fstab

systemctl daemon-reload                              # Reload mount units
mount /nfs                                           # Mount root NFS

mkdir -p /nfs/home /nfs/data /nfs/rlibs              # Create standard subdirectories

# Add /home mapping to NFS (user homes on NFS share)
echo "${nfs_server_ip}:/filestore/home /home nfs vers=3,rw,hard,noatime,rsize=65536,wsize=65536,timeo=600,_netdev 0 0" \
| sudo tee -a /etc/fstab

systemctl daemon-reload                              # Reload units again
mount /home                                          # Mount /home from NFS

# ---------------------------------------------------------------------------------
# Section 2: Join Active Directory Domain
# ---------------------------------------------------------------------------------

# Pull AD admin credentials from GCP Secret Manager

secretValue=$(gcloud secrets versions access latest --secret="admin-ad-credentials")
admin_password=$(echo $secretValue | jq -r '.password')      # Extract password
admin_username=$(echo $secretValue | jq -r '.username' | sed 's/.*\\//') # Extract username w/o domain

# Join the Active Directory domain using the `realm` command.
# - ${domain_fqdn}: The fully qualified domain name (FQDN) of the AD domain.
# - Log the output and errors to /tmp/join.log for debugging.
echo -e "$admin_password" | sudo /usr/sbin/realm join -U "$admin_username" \
    ${domain_fqdn} --verbose \
    >> /root/join.log 2>> /root/join.log

# ---------------------------------------------------------------------------------
# Section 3: Enable Password Authentication for AD Users
# ---------------------------------------------------------------------------------
# Update SSHD configuration to allow password-based logins (required for AD users)
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# ---------------------------------------------------------------------------------
# Section 4: Configure SSSD for AD Integration
# ---------------------------------------------------------------------------------
# Adjust SSSD settings for simplified user experience:
#   - Use short usernames instead of user@domain
#   - Disable ID mapping to respect AD-assigned UIDs/GIDs
#   - Adjust fallback homedir format
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' \
    /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' \
    /etc/sssd/sssd.conf
sudo sed -i 's/^access_provider = ad$/access_provider = simple\nsimple_allow_groups = ${force_group}/' /etc/sssd/sssd.conf

# Prevent XAuthority warnings for new AD users
ln -s /nfs /etc/skel/nfs
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Enable automatic home directory creation and restart services
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart ssh
sudo systemctl restart sssd
sudo systemctl restart rstudio-server
sudo systemctl enable rstudio-server

# ---------------------------------------------------------------------------------
# Section 5: Grant Sudo Privileges to AD Admin Group
# ---------------------------------------------------------------------------------
# Members of "linux-admins" AD group get passwordless sudo access
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/10-linux-admins

# ---------------------------------------------------------------------------------
# Section 6: Enforce Home Directory Permissions
# ---------------------------------------------------------------------------------
# Force new home directories to have mode 0700 (private)
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# ---------------------------------------------------------------------------------
# Section 7: Configure R Library Paths to include /nfs/rlibs
# ---------------------------------------------------------------------------------

cat <<'EOF' | sudo tee /usr/lib/R/etc/Rprofile.site > /dev/null
local({
  userlib <- Sys.getenv("R_LIBS_USER")
  if (!dir.exists(userlib)) {
    dir.create(userlib, recursive = TRUE, showWarnings = FALSE)
  }
  nfs <- "/nfs/rlibs"
  .libPaths(c(userlib, nfs, .libPaths()))
})
EOF

chgrp rstudio-admins /nfs/rlibs

# =================================================================================
# End of Script
# =================================================================================

uptime >> /root/userdata.log 2>&1
touch "$FLAG_FILE"
