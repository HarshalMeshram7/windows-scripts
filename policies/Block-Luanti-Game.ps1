# Run as Administrator
# Usage: .\block-exe-apps.ps1 chrome, postman, Teams, Notepad


$AppNames = @(
    "luanti"
)


# ============================================================
# LOGGING SETUP
# ============================================================

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\block-apps_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine   = "[$timestamp] [$Level] $Message"

    Add-Content -Path $LogFile -Value $logLine

    switch ($Level) {
        "INFO"    { Write-Host $logLine -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "WARNING" { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logLine -ForegroundColor Red }
    }
}

# ---- Session header ----
Add-Content -Path $LogFile -Value ""
Add-Content -Path $LogFile -Value "========================================"
Add-Content -Path $LogFile -Value "  block-exe-apps.ps1  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $LogFile -Value "========================================"

Write-Log "Script started. Log file: $LogFile" "INFO"
Write-Log "Raw input app names: $($AppNames -join ', ')" "INFO"

# ============================================================
# CLEAN UP APP NAMES
# ============================================================

$AppNames = $AppNames | ForEach-Object { $_.Trim().Trim(',') } | Where-Object { $_ -ne "" }
Write-Log "Cleaned app names: $($AppNames -join ', ')" "INFO"

$blockedExe = @()

# ============================================================
# CREATE POPUP SCRIPT AUTOMATICALLY
# ============================================================

$PopupScriptPath = "C:\Windows\BlockedAppPopup.ps1"

if (-not (Test-Path $PopupScriptPath)) {

$PopupScript = @'
param($BlockedApp)

Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show(
"This app has been blocked by your administrator.",
"Application Blocked",
"OK",
"Warning"
)
'@

    $PopupScript | Out-File $PopupScriptPath -Encoding UTF8 -Force
}

$DebuggerPath = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Windows\BlockedAppPopup.ps1'

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "        Blocking EXE Applications       " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta
Write-Log "--- Blocking EXE apps via Registry ---" "INFO"

# ============================================================
# BLOCK EXE APPS VIA REGISTRY
# ============================================================

foreach ($app in $AppNames) {

    $cleanName = $app -replace '\.exe$', ''
    $exeName   = "$cleanName.exe"
    $RegPath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

    try {
        New-Item -Path $RegPath -Force | Out-Null
        New-ItemProperty `
            -Path $RegPath `
            -Name "Debugger" `
            -PropertyType String `
            -Value $DebuggerPath `
            -Force | Out-Null

        Write-Host "  BLOCKED (EXE): $exeName" -ForegroundColor Red
        Write-Log "Successfully blocked EXE app via registry: $exeName  |  RegPath: $RegPath" "SUCCESS"

        $blockedExe += $exeName
    }
    catch {
        Write-Host "  FAILED to block (EXE): $exeName" -ForegroundColor Red
        Write-Log "Failed to block EXE app '$exeName'. Error: $($_.Exception.Message)" "ERROR"
    }
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "             BLOCK SUMMARY              " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Log "--- Block Summary ---" "INFO"

if ($blockedExe.Count -gt 0) {
    Write-Host "`nEXE Apps Blocked (Registry):" -ForegroundColor Yellow
    $blockedExe | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
        Write-Log "EXE blocked: $_" "SUCCESS"
    }
}

if ($blockedExe.Count -eq 0) {
    Write-Host "`nNo EXE apps were blocked." -ForegroundColor Yellow
    Write-Log "No EXE apps were blocked. Check input names and try again." "WARNING"
}

Write-Host "`n---- Completed Blocking Applications ----`n" -ForegroundColor Green
Write-Log "Script completed. EXE blocked: $($blockedExe.Count)" "SUCCESS"
Write-Log "Full log saved to: $LogFile" "INFO"
Add-Content -Path $LogFile -Value "========================================"