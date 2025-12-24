# BlockSocialMedia.ps1

param(
    [Parameter(Mandatory = $true)]
    [Array]$socialMediaUrls
)

# Path to the hosts file
$hostsFilePath = "C:\Windows\System32\drivers\etc\hosts"

# Function to get the list of currently blocked URLs in the hosts file
function Get-BlockedUrlsFromHostsFile {
    $blockedUrls = @()
    if (Test-Path $hostsFilePath) {
        $lines = Get-Content $hostsFilePath
        foreach ($line in $lines) {
            if ($line -match "127.0.0.1\s+(.+)") {
                $blockedUrls += $matches[1]
            }
        }
    } else {
        Write-Host "Hosts file not found!"
    }
    return $blockedUrls
}

# Function to get the list of currently blocked URLs in the Windows Firewall
function Get-BlockedUrlsFromFirewall {
    $blockedUrls = @()
    $firewallRules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Block*" }
    foreach ($rule in $firewallRules) {
        $remoteAddress = $rule | Get-NetFirewallAddressFilter | Select-Object -ExpandProperty RemoteAddress
        if ($remoteAddress) {
            $blockedUrls += $remoteAddress
        }
    }
    return $blockedUrls
}

# Function to resolve a URL to its IP address
function Resolve-UrlToIp {
    param (
        [string]$url
    )
    try {
        $ip = [System.Net.Dns]::GetHostAddresses($url)[0].ToString()
        return $ip
    } catch {
        Write-Host "Error resolving IP for $url"
        return $null
    }
}

# Function to block URLs in the hosts file
function Block-UrlsInHostsFile {
    param (
        [Array]$urls
    )
    if (-not (Test-Path $hostsFilePath)) {
        Write-Host "Hosts file not found."
        return
    }
    
    foreach ($url in $urls) {
        $url = $url.Trim()
        $ip = Resolve-UrlToIp -url $url
        if ($ip) {
            $line = "127.0.0.1    $url"
            $existingLines = Get-Content $hostsFilePath
            if ($existingLines -notcontains $line) {
                Add-Content -Path $hostsFilePath -Value $line
                Write-Host "Blocked in hosts file: $url"
            }
        }
    }
}

# Function to unblock URLs from the hosts file
function Unblock-UrlsInHostsFile {
    param (
        [Array]$urls
    )
    $existingLines = Get-Content $hostsFilePath
    $newLines = $existingLines

    foreach ($url in $urls) {
        $url = $url.Trim()
        $line = "127.0.0.1    $url"

        # Only remove lines that contain actual social media URLs (avoid removing system lines like 127.0.0.1)
        $newLines = $newLines | Where-Object { $_ -notmatch "127.0.0.1\s+$url" }

        if ($existingLines.Count -ne $newLines.Count) {
            $newLines | Set-Content $hostsFilePath
            Write-Host "Unblocked from hosts file: $url"
        }
    }
}

# Function to block URLs in the Windows Firewall
function Block-UrlsUsingFirewall {
    param (
        [Array]$urls
    )
    foreach ($url in $urls) {
        $url = $url.Trim()
        $ip = Resolve-UrlToIp -url $url
        if ($ip) {
            $existingRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Block $url" }
            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName "Block $url" -Direction Outbound -RemoteAddress $ip -Action Block
                Write-Host "Blocked in firewall: $url"
            }
        }
    }
}

# Function to unblock URLs from the Windows Firewall
function Unblock-UrlsUsingFirewall {
    param (
        [Array]$urls
    )
    foreach ($url in $urls) {
        $url = $url.Trim()
        $existingRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Block $url" }
        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName "Block $url"
            Write-Host "Unblocked from firewall: $url"
        }
    }
}

# Get current blocked URLs
$blockedFromHosts = Get-BlockedUrlsFromHostsFile
$blockedFromFirewall = Get-BlockedUrlsFromFirewall

# Combine both blocked lists (hosts and firewall)
$allBlockedUrls = $blockedFromHosts + $blockedFromFirewall

# URLs that need to be blocked (present in the provided array)
$urlsToBlock = $socialMediaUrls | Where-Object { $_ -notin $allBlockedUrls }

# URLs that need to be unblocked (currently blocked but not in the provided array)
$urlsToUnblock = $allBlockedUrls | Where-Object { $_ -notin $socialMediaUrls }

# Block the URLs that are in the array but not already blocked
if ($urlsToBlock.Count -gt 0) {
    Block-UrlsInHostsFile -urls $urlsToBlock
    Block-UrlsUsingFirewall -urls $urlsToBlock
}

# Unblock the URLs that are currently blocked but not in the array
if ($urlsToUnblock.Count -gt 0) {
    Unblock-UrlsInHostsFile -urls $urlsToUnblock
    Unblock-UrlsUsingFirewall -urls $urlsToUnblock
}

Write-Host "Processing completed."
