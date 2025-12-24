param (
    [string]$PayloadJson
)

$Payload = $PayloadJson | ConvertFrom-Json
$Action = $Payload.action
$BlockList = $Payload.domains

$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
$backup = "$hosts.mdmbackup"
$tempHosts = "$env:TEMP\hosts_new_mdm.txt"

# Ensure admin
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Must be run as Administrator"
    exit 1
}

# Backup
if (-not (Test-Path $backup)) {
    Copy-Item $hosts $backup -Force
}

$original = Get-Content $hosts -ErrorAction SilentlyContinue

function Expand-Domains {
    param ($Domains)
    $expanded = @()
    foreach ($d in $Domains) {
        $d = $d.ToLower().Trim()
        $expanded += $d
        if (-not $d.StartsWith("www.")) {
            $expanded += "www.$d"
        }
    }
    return $expanded | Sort-Object -Unique
}

$ExpandedDomains = Expand-Domains $BlockList

switch ($Action) {

    "enable" {
        Write-Host "Enabling DNS/Hosts blocking..."

        Set-Content -Path $tempHosts -Value $original

        foreach ($domain in $ExpandedDomains) {
            if (-not ($original -match "127\.0\.0\.1\s+$domain")) {
                Add-Content $tempHosts "127.0.0.1`t$domain"
            }
            if (-not ($original -match "::1\s+$domain")) {
                Add-Content $tempHosts "::1`t$domain"
            }
        }

        Copy-Item $tempHosts $hosts -Force
        Remove-Item $tempHosts -Force
    }

    "disable" {
        Write-Host "Disabling DNS/Hosts blocking..."

        $filtered = $original | Where-Object {
            $line = $_
            -not ($ExpandedDomains | Where-Object { $line -match "(\s|^)$($_)(\s|$)" })
        }

        Set-Content -Path $hosts -Value $filtered
    }

    default {
        Write-Error "Unknown action"
        exit 1
    }
}

# Permissions
cmd /c 'icacls "%SystemRoot%\System32\drivers\etc\hosts" /inheritance:r /grant SYSTEM:(F) /grant Administrators:(F) /grant Users:(R)'

# Flush DNS
ipconfig /flushdns | Out-Null

Write-Output '{"status":"success","dns_host_filter_enabled":true}'
 