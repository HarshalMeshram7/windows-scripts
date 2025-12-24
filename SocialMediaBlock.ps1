param(
    [Parameter(Mandatory = $true)]
    [string[]]$socialMediaUrls
)

# Requires admin
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script as Administrator."
    exit 1
}

$hostsFilePath = "C:\Windows\System32\drivers\etc\hosts"

# ------------------ HELPERS ------------------

function Resolve-UrlToIp {
    param ([string]$url)
    try {
        return ([System.Net.Dns]::GetHostAddresses($url) |
            Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
            Select-Object -First 1).ToString()
    } catch {
        return $null
    }
}

function Get-BlockedUrlsFromHostsFile {
    if (-not (Test-Path $hostsFilePath)) { return @() }

    Get-Content $hostsFilePath | ForEach-Object {
        if ($_ -match '^\s*127\.0\.0\.1\s+([a-zA-Z0-9\.\-]+)\s*$') {
            $matches[1]
        }
    }
}

function Get-BlockedUrlsFromFirewall {
    Get-NetFirewallRule |
        Where-Object { $_.DisplayName -like "Block *" } |
        ForEach-Object {
            $_.DisplayName -replace '^Block\s+', ''
        }
}

# ------------------ HOSTS FILE ------------------

function Block-UrlsInHostsFile {
    param ([string[]]$urls)

    $existing = Get-Content $hostsFilePath -ErrorAction Stop
    $newLines = @($existing)

    foreach ($url in $urls) {
        if ($existing -notmatch "^\s*127\.0\.0\.1\s+$([regex]::Escape($url))\s*$") {
            $newLines += "127.0.0.1    $url"
            Write-Host "Blocked in hosts file: $url"
        }
    }

    if ($newLines.Count -ne $existing.Count) {
        Set-Content -Path $hostsFilePath -Value $newLines -Force
    }
}

function Unblock-UrlsInHostsFile {
    param ([string[]]$urls)

    $existing = Get-Content $hostsFilePath -ErrorAction Stop
    $filtered = $existing

    foreach ($url in $urls) {
        $escaped = [regex]::Escape($url)
        $filtered = $filtered | Where-Object {
            $_ -notmatch "^\s*127\.0\.0\.1\s+$escaped\s*$"
        }
    }

    if ($filtered.Count -ne $existing.Count) {
        Set-Content -Path $hostsFilePath -Value $filtered -Force
        Write-Host "Hosts file updated."
    }
}

# ------------------ FIREWALL ------------------

function Block-UrlsUsingFirewall {
    param ([string[]]$urls)

    foreach ($url in $urls) {
        if (-not (Get-NetFirewallRule -DisplayName "Block $url" -ErrorAction SilentlyContinue)) {
            $ip = Resolve-UrlToIp $url
            if ($ip) {
                New-NetFirewallRule `
                    -DisplayName "Block $url" `
                    -Direction Outbound `
                    -RemoteAddress $ip `
                    -Action Block `
                    -Profile Any | Out-Null

                Write-Host "Blocked in firewall: $url"
            }
        }
    }
}

function Unblock-UrlsUsingFirewall {
    param ([string[]]$urls)

    foreach ($url in $urls) {
        Get-NetFirewallRule -DisplayName "Block $url" -ErrorAction SilentlyContinue |
            Remove-NetFirewallRule
        Write-Host "Unblocked from firewall: $url"
    }
}

# ------------------ MAIN LOGIC ------------------

$blockedHosts    = Get-BlockedUrlsFromHostsFile
$blockedFirewall = Get-BlockedUrlsFromFirewall
$allBlocked      = ($blockedHosts + $blockedFirewall) | Sort-Object -Unique

$urlsToBlock   = $socialMediaUrls | Where-Object { $_ -notin $allBlocked }
$urlsToUnblock = $allBlocked | Where-Object { $_ -notin $socialMediaUrls }

if ($urlsToBlock.Count -gt 0) {
    Block-UrlsInHostsFile -urls $urlsToBlock
    Block-UrlsUsingFirewall -urls $urlsToBlock
}

if ($urlsToUnblock.Count -gt 0) {
    Unblock-UrlsInHostsFile -urls $urlsToUnblock
    Unblock-UrlsUsingFirewall -urls $urlsToUnblock
}

Write-Host "Processing completed."
