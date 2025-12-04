<#
DNS / HOST FILTERING WITH SAFE OVERWRITE
Blocks websites for ALL child accounts without touching admin accounts
Uses safe temp-file replacement to avoid "file in use" errors
#>

Write-Host "Applying DNS/Host filtering..."

$BlockList = @(
    "facebook.com",
    "www.facebook.com",
    "youtube.com",
    "www.youtube.com",
    "instagram.com",
    "www.instagram.com",
    "tiktok.com",
    "www.tiktok.com",
    "discord.com",
    "www.discord.com"
)

$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$backup = "$hosts.mdmbackup"
$tempHosts = "$env:TEMP\hosts_new_mdm.txt"

# Backup original hosts file (only once)
if (-not (Test-Path $backup)) {
    Copy-Item $hosts $backup -Force
}

# Read original hosts file
$original = Get-Content $hosts -ErrorAction SilentlyContinue

# Write new hosts file to temp
Set-Content -Path $tempHosts -Value $original

foreach ($domain in $BlockList) {
    Add-Content -Path $tempHosts -Value "127.0.0.1`t$domain"
    Add-Content -Path $tempHosts -Value "::1`t$domain"
}

# Replace original hosts safely
Copy-Item $tempHosts $hosts -Force

# Set permissions
icacls $hosts /inheritance:r `
    /grant "SYSTEM:(F)" `
    /grant "Administrators:(F)" `
    /grant "ParentAdmin:(F)" `
    /grant "Users:(R)" | Out-Null

Remove-Item $tempHosts -Force -ErrorAction SilentlyContinue

Write-Output '{"status":"success","dns_host_filter_enabled":1}'
