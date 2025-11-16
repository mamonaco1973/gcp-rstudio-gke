#!/bin/bash
# ================================================================================================
# Script Purpose:
# Automates system preparation for Active Directory (AD) integration, Samba/Winbind configuration,
# NFS mounting, SSH/SSSD adjustments, sudo delegation, and permission enforcement.
# Designed for cloud-based Linux environments joining a Samba AD domain.
# ================================================================================================

FLAG_FILE="/root/.nfs_provisioned"

#--------------------------------------------------------------------
# Prevent join from happening after first boot
#--------------------------------------------------------------------

if [ -f "$FLAG_FILE" ]; then
  echo "Provisioning already completed — skipping." >> /root/userdata.log 2>&1
  exit 0
fi

# ---------------------------------------------------------------------------------
# Section 1: Update the OS and Install Required Packages
# ---------------------------------------------------------------------------------

apt-get update -y >> /root/userdata.log 2>&1   # Refresh package lists for latest versions
export DEBIAN_FRONTEND=noninteractive          # Prevent interactive prompts during installs

# Install packages for AD integration, NFS, and Samba:
# - realmd / sssd-* / adcli: Enable AD discovery/join and user authentication
# - libnss-sss / libpam-sss: NSS/PAM integration for SSSD
# - samba-* / winbind: Samba and Winbind for AD + SMB integration
# - oddjob / oddjob-mkhomedir: Auto-create home dirs on first login
# - krb5-user: Kerberos tools for authentication
# - nfs-common: NFS client utilities
# - stunnel4: TLS tunneling (optional, for secure services)
# - Editors (nano/vim) + utilities (less/unzip)
apt-get install -y less unzip realmd sssd-ad sssd-tools libnss-sss \
    libpam-sss adcli samba samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit krb5-user nano vim nfs-common \
    winbind libpam-winbind libnss-winbind stunnel4 >> /root/userdata.log 2>&1

# ---------------------------------------------------------------------------------
# Section 2: Mount NFS file system
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
# Section 3: Join the Active Directory Domain
# ---------------------------------------------------------------------------------

# Pull AD admin credentials from GCP Secret Manager
secretValue=$(gcloud secrets versions access latest --secret="admin-ad-credentials")
admin_password=$(echo $secretValue | jq -r '.password')      # Extract password
admin_username=$(echo $secretValue | jq -r '.username' | sed 's/.*\\//') # Extract username w/o domain

# Use `realm` to join the AD domain (via Samba membership software)
# Credentials piped in securely, logs captured for troubleshooting
echo -e "$admin_password" | sudo /usr/sbin/realm join --membership-software=samba \
    -U "$admin_username" ${domain_fqdn} --verbose >> /root/join.log 2>&1
    
# ---------------------------------------------------------------------------------
# Section 4: Allow Password Authentication for AD Users
# ---------------------------------------------------------------------------------

# Enable password authentication for SSH (disabled by default in many cloud images)
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' \
    /etc/ssh/sshd_config.d/60-cloudimg-settings.conf

# ---------------------------------------------------------------------------------
# Section 5: Configure SSSD for AD Integration
# ---------------------------------------------------------------------------------

# Adjust SSSD settings:
# - Simplify login (no user@domain required)
# - Use AD-provided UID/GID (disable ID mapping)
# - Switch to simple access provider (allow all)
# - Set fallback homedir to /home/%u instead of user@domain
sudo sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' /etc/sssd/sssd.conf
sudo sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/g' /etc/sssd/sssd.conf
sudo sed -i 's/access_provider = ad/access_provider = simple/g' /etc/sssd/sssd.conf
sudo sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|' /etc/sssd/sssd.conf

# Prevent XAuthority warnings by pre-creating .Xauthority in /etc/skel
touch /etc/skel/.Xauthority
chmod 600 /etc/skel/.Xauthority

# Apply changes: update PAM, restart services
sudo pam-auth-update --enable mkhomedir
sudo systemctl restart sssd
sudo systemctl restart ssh

# ---------------------------------------------------------------------------------
# Section 6: Configure Samba File Server
# ---------------------------------------------------------------------------------

sudo systemctl stop sssd                             # Stop SSSD temporarily to modify Samba config

# Write Samba configuration w/ AD + Winbind integration, performance tuning, and ACL defaults
cat <<EOT > /tmp/smb.conf
[global]
workgroup = ${netbios}
security = ads

# Performance tuning
strict sync = no
sync always = no
aio read size = 1
aio write size = 1
use sendfile = yes

passdb backend = tdbsam

# Printing subsystem (legacy, usually unused in cloud)
printing = cups
printcap name = cups
load printers = yes
cups options = raw

kerberos method = secrets and keytab

# Default user template
template homedir = /home/%U
template shell = /bin/bash
#netbios 

# File creation masks
create mask = 0770
force create mode = 0770
directory mask = 0770
force group = ${force_group}

realm = ${realm}

# ID mapping configuration
idmap config ${realm} : backend = sss
idmap config ${realm} : range = 10000-1999999999
idmap config * : backend = tdb
idmap config * : range = 1-9999

# Winbind options
min domain uid = 0
winbind use default domain = yes
winbind normalize names = yes
winbind refresh tickets = yes
winbind offline logon = yes
winbind enum groups = yes
winbind enum users = yes
winbind cache time = 30
idmap cache time = 60

[homes]
comment = Home Directories
browseable = No
read only = No
inherit acls = Yes

[nfs]
comment = Mounted NFS area
path = /nfs
read only = no
guest ok = no
EOT

# Deploy Samba configuration
sudo cp /tmp/smb.conf /etc/samba/smb.conf
sudo rm /tmp/smb.conf

# Dynamically set NetBIOS name from hostname (uppercase, 15-char limit)

value=$(hostname | cut -c1-15)
netbios=$(echo "$value" | tr '[:lower:]' '[:upper:]')
sudo sed -i "s/#netbios/netbios name=$netbios/g" /etc/samba/smb.conf

# Add 'sss' and 'winbind' to the `passwd` line
sudo sed -i '/^passwd:/ s/$/ sss winbind/' /etc/nsswitch.conf

# Add 'sss' and 'winbind' to the `group` line
sudo sed -i '/^group:/ s/$/ sss winbind/' /etc/nsswitch.conf

sudo cp /tmp/nsswitch.conf /etc/nsswitch.conf
sudo rm /tmp/nsswitch.conf

# Restart Samba/Winbind/SSSD services to activate configuration
sudo systemctl restart winbind smb nmb sssd

# ---------------------------------------------------------------------------------
# Section 7: Grant Sudo Privileges to AD Linux Admins
# ---------------------------------------------------------------------------------

# Allow AD group "linux-admins" passwordless sudo access
sudo echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/10-linux-admins

# ---------------------------------------------------------------------------------
# Section 8: Enforce Home Directory Permissions
# ---------------------------------------------------------------------------------

# Ensure new home directories default to 0700 (private)
sudo sed -i 's/^\(\s*HOME_MODE\s*\)[0-9]\+/\10700/' /etc/login.defs

# Trigger home directory creation for test users (forces mkhomedir execution)

ln -s /nfs /etc/skel/nfs

su -c "exit" rpatel
su -c "exit" jsmith
su -c "exit" akumar
su -c "exit" edavis

# Set NFS directory ownership and permissions
chgrp ${force_group} /nfs
chgrp ${force_group} /nfs/data
chgrp ${force_group} /nfs/rlibs

chmod 2770 /nfs
chmod 2775 /nfs/rlibs
chmod 2770 /nfs/data
chmod 700 /home/*

# Clone helper repo into /nfs and apply group permissions
cd /nfs
git clone https://github.com/mamonaco1973/gcp-rstudio-cluster.git
chmod -R 775 gcp-rstudio-cluster
chgrp -R rstudio-users gcp-rstudio-cluster

uptime >> /root/userdata.log 2>&1
touch "$FLAG_FILE"