# GCP RStudio Cluster with Filestore-Backed Shared Libraries  

This project extends the original **GCP Mini Active Directory** lab by deploying an **RStudio Server cluster** on Google Cloud Platform. The cluster is designed for data science and analytics workloads, where multiple users need a scalable, domain-joined environment with consistent package management.  

![RStudio](rstudio.png)  

Instead of relying only on per-user libraries stored on ephemeral VM disks, this solution integrates **Google Cloud Filestore** as a shared package and data backend. This allows RStudio nodes in a **Managed Instance Group (MIG)** to mount a common NFS share, ensuring that installed R packages and project files are accessible across all nodes.  

### Key capabilities demonstrated:  

1. **RStudio Server Cluster with Global HTTP Load Balancer** – RStudio Server (Open Source Edition) deployed across multiple Compute Engine instances, fronted by a GCP global HTTP(S) load balancer for high availability and seamless user access.  
2. **Filestore-Backed Shared Library** – Filestore NFS share mounted at `/nfs/rlibs` and injected into `.libPaths()`, enabling shared R package storage across the cluster.  
3. **Mini Active Directory Integration** – A Samba-based mini-AD domain controller provides authentication and DNS, so RStudio logins are domain-based and centrally managed.  

Together, this architecture provides a reproducible, cloud-native RStudio environment where users get both personal home-directory libraries and access to a shared, scalable package repository.  

![GCP RStudio Cluster](gcp-rstudio-cluster.png)  

## Prerequisites

* [A Google Cloud Account](https://console.cloud.google.com/)
* [Install gcloud CLI](https://cloud.google.com/sdk/docs/install) 
* [Install Latest Terraform](https://developer.hashicorp.com/terraform/install)
* [Install Latest Packer](https://developer.hashicorp.com/packer/install)

If this is your first time watching our content, we recommend starting with this video: [GCP + Terraform: Easy Setup](https://youtu.be/3spJpYX4f7I). It provides a step-by-step guide to properly configure Terraform, Packer, and the gcloud CLI.

## Build WorkFlow

![Build WorkFlow](build-workflow.png)

## Download this Repository  

Clone the repository from GitHub and move into the project directory:  

```bash
git clone https://github.com/mamonaco1973/gcp-rstudio-cluster.git
cd gcp-rstudio-cluster
```  


## Build the Code  

Run [check_env](check_env.sh) to validate your environment, then run [apply](apply.sh) to provision the infrastructure.  

```bash
develop-vm:~/gcp-rstudio-cluster$ ./apply.sh
NOTE: Validating that required commands are in PATH.
NOTE: gcloud is found in the current PATH.
NOTE: terraform is found in the current PATH.
NOTE: All required commands are available.
NOTE: Checking Google Cloud CLI connection.
NOTE: Successfully authenticated with GCP.
Initializing provider plugins...
Terraform has been successfully initialized!
```  
## Build Results  

When the deployment completes, the following resources are created:  

- **Networking:**  
  - A custom VPC with dedicated subnets for Active Directory, MIG cluster nodes, and NFS Gateway.  
  - Route tables and firewall rules configured for outbound internet access, AD lookups, and Filestore access  

- **Security & Identity:**  
  - Firewall rules scoped to domain controller, MIG nodes, and NFS gateway  
  - Google Secret Manager entries for administrator and user credentials  
  - Service accounts and IAM roles for MIG instances to securely fetch secrets  

- **Active Directory Server:**  
  - Ubuntu VM running Samba 4 as Domain Controller and DNS server  
  - Configured Kerberos realm and NetBIOS name for authentication  
  - Administrator credentials securely stored in Secret Manager  

- **RStudio Cluster (MIG):**  
  - Linux Managed Instance Group (MIG) hosting RStudio Server nodes built from a Packer-generated custom image  
  - Global HTTP(S) Load Balancer providing public access, load balancing, health checks, and optional session affinity  
  - Autoscaling policies to add/remove RStudio nodes based on CPU utilization  

- **Filestore Storage:**  
  - Google Cloud Filestore instance providing an NFSv3 share  
  - Mounted at `/nfs/rlibs` for shared R libraries and optionally `/nfs/home` for user home directories  

- **File Access Integration:**  
  - RStudio MIG instances mount the Filestore NFS share for shared R libraries and project data  
  - A Linux gateway can optionally expose the same Filestore backend via Samba for Windows clients  
  - This provides a unified storage backend across Linux (NFS) and Windows (SMB) clients  

- **Sample R Workloads:**  
  - Example R scripts (Monte Carlo, bell curve, surface plotting, etc.) included to validate the environment  

## Users and Groups

The domain controller provisions **sample users and groups** via Terraform templates. These are intended for testing and demonstration.  

### Groups Created  

| Group Name    | Category  | Scope     | gidNumber |
|---------------|-----------|----------|-----------|
| rstudio-users  | Security  | Universal | 10001 |
| india         | Security  | Universal | 10002 |
| us            | Security  | Universal | 10003 |
| linux-admins  | Security  | Universal | 10004 |
| rstudio-admins  | Security  | Universal | 10005 |

### Users Created  

| Username | Full Name   | uidNumber | gidNumber | Groups Joined                    |
|----------|-------------|-----------|-----------|----------------------------------|
| jsmith   | John Smith  | 10001     | 10001     | rstudio-users, us, linux-admins, rstudio-admins  |
| edavis   | Emily Davis | 10002     | 10001     | rstudio-users, us                 |
| rpatel   | Raj Patel   | 10003     | 10001     | rstudio-users, india, linux-admins, rstudio-admins|
| akumar   | Amit Kumar  | 10004     | 10001     | rstudio-users, india              |


### Understanding `uidNumber` and `gidNumber` for Linux Integration

The **`uidNumber`** (User ID) and **`gidNumber`** (Group ID) attributes are critical when integrating **Active Directory** with **Linux systems**, particularly in environments where **SSSD** ([System Security Services Daemon](https://sssd.io/)) or similar services are used for identity management. These attributes allow Linux hosts to recognize and map Active Directory users and groups into the **POSIX** (Portable Operating System Interface) user and group model.

### Creating a New RStudio User

Follow these steps to provision a new user in the Active Directory domain and validate their access to the RStudio cluster:

1. **Connect to the Domain Controller**  
   - Log into the **`win-ad-xxxx`** server via a **RDP** client
   - Use the `rpatel` or `jsmith` credentials that were provisioned during cluster deployment.  

2. **Launch Active Directory Users and Computers (ADUC)**  
   - From the Windows Start menu, open **“Active Directory Users and Computers.”**  
   - Enable **Advanced Features** under the **View** menu. This ensures you can access the extended attribute tabs (e.g., UID/GID mappings).  

3. **Navigate to the Users Organizational Unit (OU)**  
   - In the left-hand tree, expand the domain (e.g., `rstudio.mikecloud.com`).  
   - Select the **Users** OU where all cluster accounts are managed.  

4. **Create a New User Object**  
   - Right-click the Users OU and choose **New → User.**  
   - Provide the following:  
     - **Full Name:** Descriptive user name (e.g., “Mike Cloud”).  
     - **User Logon Name (User Principal Name / UPN):** e.g., `mcloud@rstudio.mikecloud.com`.  
     - **Initial Password:** Set an initial password.

![Windows](windows.png)

5. **Assign a Unique UID Number**  
   - Open **PowerShell** on the AD server.  
   - Run the script located at:  
     ```powershell
     Z:\nfs\gcp-rstudio-cluster\06-utils\getNextUID.bat
     ```  
   - This script returns the next available **`uidNumber`** to assign to the new account.  

6. **Configure Advanced Attributes**  
   - In the new user’s **Properties** dialog, open the **Attribute Editor** tab.  
   - Set the following values:  
     - `gidNumber` → **10001** (the shared GID for the `rstudio-users` group).  
     - `uid` → match the user’s AD login ID (e.g., `rpatel`).  
     - `uidNumber` → the unique numeric value returned from `getNextUID.ps1`.  

7. **Add Group Memberships**  
   - Go to the **Member Of** tab.  
   - Add the user to the following groups:  
     - **rstudio-users** → grants standard RStudio access.  
     - **us** (or other geographic/departmental group as applicable).  

8. **Validate User on Linux**  
   - Open an **SSH** session to the **`nfs-gateway-xxxx`** instance.  
   - Run the following command to confirm the user’s identity mapping:  
     ```bash
     id mcloud
     ```  
   - Verify that the output shows the correct **UID**, **GID**, and group memberships (e.g., `rstudio-users`).  

![Linux](linux.png)

9. **Validate RStudio Access**  
   - Open the RStudio cluster’s Application Gateway's URL in a browser (e.g., `http://34.173.20.15/`).  
   - Log in with the new AD credentials.  

10. **Verify Permissions**  
   - By default, the new user is **not** a member of the `rstudio-admin` group.  
   - Attempting to install packages into the **shared library path `/nfs/rlibs`** should fail with a **“Permission denied”** error.  
   - This confirms the user is restricted to installing packages in their **personal user library** only.  

---

✅ **Note:** If you need the user to have administrative rights (e.g., the ability to install packages into the shared library), add them to the **rstudio-admin** group in addition to `rstudio-users`.

### Clean Up  

When finished, remove all resources with:  

```bash
./destroy.sh
```  
