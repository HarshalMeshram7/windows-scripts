<#
.SYNOPSIS
  Applies local MDM-style application restrictions.
.DESCRIPTION
  - Blocks classic EXE apps using IFEO
  - Removes Store apps for all users
  - Disables Microsoft Store & App Installer
  - Safe to run multiple times
.NOTES
  Must be executed as SYSTEM or Administrator
#>

# =========================
# CONFIGURATION
# =========================
$ExeBlockList = @(
    "chrome.exe"
)

$StoreAppsToRemove = @(
    "MSTeams",
    "Microsoft.WindowsStore"
)

$DisableStore = $true
$DisableAppInstaller = $true

# =========================
# FUNCTIONS
# =========================

function Block-ExeIFEO {
    param ([string[]]$ExeNames)

    foreach ($exe in $ExeNames) {
        $key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe"

        if (-not (Test-Path $key)) {
            New-Item -Path $key -Force | Out-Null
        }

        New-ItemProperty `
            -Path $key `
            -Name "Debugger" `
            -Value "C:\Windows\System32\blocked.exe" `
            -PropertyType String `
            -Force | Out-Null
    }
}

function Remove-StoreApps {
    param ([string[]]$Packages)

    foreach ($pkg in $Packages) {
        Get-AppxPackage -Name $pkg -AllUsers |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }
}

function Disable-StoreAccess {
    if ($DisableStore) {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" `
            /v RemoveWindowsStore /t REG_DWORD /d 1 /f | Out-Null
    }

    if ($DisableAppInstaller) {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" `
            /v EnableAppInstaller /t REG_DWORD /d 0 /f | Out-Null
    }
}

# =========================
# APPLY POLICY
# =========================

Write-Output "Applying MDM policy..."

Block-ExeIFEO -ExeNames $ExeBlockList
Remove-StoreApps -Packages $StoreAppsToRemove
Disable-StoreAccess

Write-Output "MDM policy applied successfully."
