<#
.SYNOPSIS
  Hybrid application blocking policy (Execution + Network)
.DESCRIPTION
  - Automatically blocks apps based on type
  - Offline apps → IFEO execution block
  - Online apps → Firewall network block
  - Safe for Windows Pro
.NOTES
  Must run as SYSTEM or Administrator
#>

Write-Output "Applying Hybrid Application Policy..."

# =========================
# INPUT (APP NAMES)
# =========================
$AppsToBlock = @(
    "chrome",
    "notepad",
    "adobe reader"
)

# =========================
# CLASSIFICATION TABLE
# =========================

# Known ONLINE apps (network-dependent)
$OnlineApps = @{
    "chrome" = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    )
    "edge" = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    )
    "teams" = @(
        "C:\Program Files\Microsoft\Teams\current\ms-teams.exe"
    )
    "adobe reader" = @(
        "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe",
        "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
    )
}

# Known OFFLINE / SYSTEM apps
$OfflineExecutables = @{
    "notepad" = @("notepad.exe")
}

# =========================
# FUNCTIONS
# =========================

function Block-ExecutionIFEO {
    param ([string[]]$ExeNames)

    foreach ($exe in $ExeNames) {
        foreach ($base in @(
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
        )) {
            $key = "$base\$exe"
            New-Item -Path $key -Force | Out-Null
            Set-ItemProperty -Path $key -Name Debugger `
                -Value "C:\Windows\System32\blocked.exe" -Type String
            Write-Output "Execution blocked: $exe"
        }
    }
}

function Block-NetworkFirewall {
    param ([string[]]$ExePaths)

    foreach ($path in $ExePaths) {
        if (-not (Test-Path $path)) { continue }

        $name = "MDM Hybrid Block - $(Split-Path $path -Leaf)"

        Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue |
            Remove-NetFirewallRule

        New-NetFirewallRule `
            -DisplayName $name `
            -Direction Outbound `
            -Program $path `
            -Action Block `
            -Profile Any

        Write-Output "Network blocked: $path"
    }
}

# =========================
# APPLY POLICY
# =========================

foreach ($app in $AppsToBlock) {

    $appKey = $app.ToLower()

    # ONLINE APP → FIREWALL BLOCK
    if ($OnlineApps.ContainsKey($appKey)) {
        Block-NetworkFirewall -ExePaths $OnlineApps[$appKey]
        continue
    }

    # OFFLINE APP → EXECUTION BLOCK
    if ($OfflineExecutables.ContainsKey($appKey)) {
        Block-ExecutionIFEO -ExeNames $OfflineExecutables[$appKey]
        continue
    }

    # UNKNOWN APP → SAFE DEFAULT (EXECUTION BLOCK)
    Write-Output "Unknown app '$app' → defaulting to execution block"
    Block-ExecutionIFEO -ExeNames @("$app.exe")
}

Write-Output "Hybrid policy applied successfully."
Write-Output "Reboot required for execution blocks."

shutdown /r /t 5
