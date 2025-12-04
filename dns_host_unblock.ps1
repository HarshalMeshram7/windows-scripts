Write-Host "Removing DNS/Host filtering..."

$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$backup = "$hosts.mdmbackup"

if (Test-Path $backup) {
    Copy-Item $backup $hosts -Force
}

icacls $hosts /reset | Out-Null

Write-Output '{"status":"success","dns_host_filter_disabled":1}'
