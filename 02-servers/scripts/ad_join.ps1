# ------------------------------------------------------------
# Install Active Directory Components
# ------------------------------------------------------------

# Suppress progress bars to speed up execution
$ProgressPreference = 'SilentlyContinue'

# Install required Windows Features for Active Directory management
Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# ------------------------------------------------------------
# Join instance to active directory
# ------------------------------------------------------------

$secretJson = gcloud secrets versions access latest --secret="admin-ad-credentials"
$secretObject = $secretJson | ConvertFrom-Json
$password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$username = $secretObject.username
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password

Add-Computer -DomainName "${domain_fqdn}" -Credential $cred -Force -ErrorAction Stop
Write-Output "Successfully joined the domain."

# ------------------------------------------------------------
# Grant RDP Access to All Users in "mcloud-users" Group
# ------------------------------------------------------------

Write-Output "Add users to the Remote Desktop Users Group"
$domainGroup = "RSTUDIO\rstudio-users"
$maxRetries = 10
$retryDelay = 30

for ($i=1; $i -le $maxRetries; $i++) {
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $domainGroup -ErrorAction Stop
        Write-Output "SUCCESS: Added $domainGroup to Remote Desktop Users"
        break
    } catch {
        Write-Output "WARN: Attempt $i failed - waiting $retryDelay seconds..."
        Start-Sleep -Seconds $retryDelay
    }
}

# ------------------------------------------------------------
# Map EFS as Persistent Drive (Z:)
# ------------------------------------------------------------

# Create a startup batch script to map Z: to the EFS share via Samba
$startup = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$batchFile = Join-Path $startup "map_drives.bat"

# Command mounts \\${nfs_gateway}\nfs persistently at logon
$command = "net use Z: \\${nfs_gateway}\nfs /persistent:yes"
Set-Content -Path $batchFile -Value $command -Encoding ASCII

# ------------------------------------------------------------
# Final Reboot to Apply Changes
# ------------------------------------------------------------

Write-Output "Finalize join with a reboot"

# Reboot the server to finalize the domain join and group policies
shutdown /r /t 5 /c "Initial reboot to join domain" /f /d p:4:1