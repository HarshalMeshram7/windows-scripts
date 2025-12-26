param(
    [Parameter(Mandatory = $true)]
    [string[]]$socialMediaUrls
)

# ------------------ ADMIN CHECK ------------------

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script as Administrator."
    exit 1
}

$hostsFilePath = "C:\Windows\System32\drivers\etc\hosts"

# ------------------ URL NORMALIZATION ------------------

function Get-HostName {
    param ([string]$inputUrl)

    try {
        if ($inputUrl -match '^https?://') {
            return ([System.Uri]$inputUrl).Host.ToLower()
        } else {
            return ($inputUrl -replace '/.*$', '').ToLower()
        }
    } catch {
        return $null
    }
}

$socialMediaUrls = $socialMediaUrls |
    ForEach-Object { Get-HostName $_ } |
    Where-Object { $_ } |
    Sort-Object -Unique

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
            $matches[1].ToLower()
        }
    }
}

function Get-BlockedUrlsFromFirewall {
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Block *" } |
        ForEach-Object {
            ($_.DisplayName -replace '^Block\s+', '').ToLower()
        }
}

# ------------------ HOSTS FILE ------------------

function Block-UrlsInHostsFile {
    param ([string[]]$urls)

    # Ensure hosts file is writable
    attrib -r $hostsFilePath

    $existing = Get-Content -Path $hostsFilePath -ErrorAction Stop
    $newLines = @($existing)

    foreach ($url in $urls) {
        $escaped = [regex]::Escape($url)
        $pattern = "^\s*127\.0\.0\.1\s+$escaped\s*$"

        if (-not ($existing -match $pattern)) {
            $newLines += "127.0.0.1    $url"
            Write-Host "Blocked in hosts file: $url"
        }
    }

    if ($newLines.Count -ne $existing.Count) {
        $content = ($newLines -join "`r`n")
        Set-Content -Path $hostsFilePath -Value $content -Encoding ASCII -Force
    }
}


function Unblock-UrlsInHostsFile {
    param ([string[]]$urls)

    attrib -r $hostsFilePath

    $existing = Get-Content -Path $hostsFilePath -ErrorAction Stop
    $filtered = $existing

    foreach ($url in $urls) {
        $escaped = [regex]::Escape($url)
        $pattern = "^\s*127\.0\.0\.1\s+$escaped\s*$"
        $filtered = $filtered | Where-Object { $_ -notmatch $pattern }
    }

    if ($filtered.Count -ne $existing.Count) {
        $content = ($filtered -join "`r`n")
        Set-Content -Path $hostsFilePath -Value $content -Encoding ASCII -Force
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

                Write-Host "Blocked in firewall: $url ($ip)"
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




#.\SocialMediaBlock.ps1 -socialMediaUrls @("www.youtube.com", "https://www.instagram.com")