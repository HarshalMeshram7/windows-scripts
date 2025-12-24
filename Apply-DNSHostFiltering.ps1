param (
    [string[]]$BlockList
)

Write-Host "Applying DNS/Host filtering..."

$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$backup = "$hosts.mdmbackup"
$tempHosts = "$env:TEMP\hosts_new_mdm.txt"

# Backup once
if (-not (Test-Path $backup)) {
    Copy-Item $hosts $backup -Force
}

# Read existing hosts
$original = Get-Content $hosts -ErrorAction SilentlyContinue
Set-Content -Path $tempHosts -Value $original

# Add blocked domains
foreach ($domain in $BlockList) {
    Add-Content $tempHosts "127.0.0.1`t$domain"
    Add-Content $tempHosts "::1`t$domain"
}

# Replace hosts file
Copy-Item $tempHosts $hosts -Force

# Set permissions (CMD-safe, NO ParentAdmin for local)
cmd /c 'icacls "%SystemRoot%\System32\drivers\etc\hosts" /inheritance:r /grant SYSTEM:(F) /grant Administrators:(F) /grant Users:(R)'

Remove-Item $tempHosts -Force -ErrorAction SilentlyContinue

Write-Output '{"status":"success","dns_host_filter_enabled":1}'
