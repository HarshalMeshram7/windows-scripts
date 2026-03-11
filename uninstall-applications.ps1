# Run as Administrator
# Usage: .\uninstall-applications.ps1 anydesk

param(
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

# ============================================================
# LOGGING SETUP
# ============================================================

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\uninstall_apps_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level="INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"

    Add-Content -Path $LogFile -Value $line

    switch ($Level) {
        "INFO"    { Write-Host $line -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $line -ForegroundColor Green }
        "WARN"    { Write-Host $line -ForegroundColor Yellow }
        "ERROR"   { Write-Host $line -ForegroundColor Red }
    }
}

Write-Log "Script started. Searching for: *$AppName*"

# ============================================================
# 1️⃣ STORE APP UNINSTALL
# ============================================================

$storeApps = Get-AppxPackage -AllUsers | Where-Object {
    $_.Name -like "*$AppName*" -or $_.PackageFamilyName -like "*$AppName*"
}

if ($storeApps) {

    foreach ($app in $storeApps) {

        Write-Log "Found Store App: $($app.PackageFullName)"

        try {

            Remove-AppxPackage -Package $app.PackageFullName -AllUsers

            Write-Log "Removed Store App: $($app.PackageFullName)" "SUCCESS"

        }
        catch {

            Write-Log "Failed removing Store App: $($app.PackageFullName)" "ERROR"

        }
    }

    # remove provisioned packages
    $prov = Get-AppxProvisionedPackage -Online | Where-Object {
        $_.DisplayName -like "*$AppName*"
    }

    foreach ($p in $prov) {

        Write-Log "Removing provisioned package: $($p.PackageName)"

        Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName

        Write-Log "Provisioned package removed: $($p.PackageName)" "SUCCESS"
    }

    Write-Log "Store app uninstall completed"
    exit
}

Write-Log "No Store apps found. Checking EXE applications..." "WARN"

# ============================================================
# 2️⃣ EXE APPLICATION UNINSTALL
# ============================================================

$paths = @(
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
"HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$found = $false

foreach ($path in $paths) {

    $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$AppName*" }

    foreach ($app in $apps) {

        $found = $true

        Write-Log "Found EXE application: $($app.DisplayName)"

        $uninstall = $app.UninstallString

        if ($uninstall -match "msiexec") {

            $productCode = ($uninstall -replace ".*({.*})",'$1')

            Write-Log "Running silent MSI uninstall"

            Start-Process "msiexec.exe" `
                -ArgumentList "/x $productCode /qn /norestart" `
                -Wait -WindowStyle Hidden

        }
        else {

            Write-Log "Running silent EXE uninstall"

            $exe = ($uninstall -split '"')[1]

            $silentArgs = "/S /silent /verysilent /quiet /norestart"

            Start-Process `
                -FilePath $exe `
                -ArgumentList $silentArgs `
                -Wait -WindowStyle Hidden
        }

        Write-Log "Uninstalled: $($app.DisplayName)" "SUCCESS"
    }
}

if (-not $found) {

    Write-Log "Application not found: $AppName" "WARN"

}

Write-Log "Script completed"