# --------------------------------------------------------------
# EXE Unblock Script (Hardcoded Apps)
# Run as Administrator
# --------------------------------------------------------------

# ============================================================
# APPS TO UNBLOCK
# ============================================================

$TargetApps = @(
    "anydesk"
)

# ============================================================
# LOGGING SETUP
# ============================================================

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\unblock_exe_apps_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"

    Add-Content -Path $LogFile -Value $line
}

Write-Log "Script started"

# --------------------------------------------------------------

$unblockedExe = @()
$notFoundApps = @()

$baseRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "      Targeted Application Unblock      " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

Write-Log "Target apps: $($TargetApps -join ', ')"

# ============================================================
# PROCESS TARGET APPS
# ============================================================

foreach ($app in $TargetApps) {

    $exeName = $app.ToLower()

    if (-not $exeName.EndsWith(".exe")) {
        $exeName = "$exeName.exe"
    }

    $regPath = "$baseRegPath\$exeName"

    if (Test-Path $regPath) {

        $debugger = Get-ItemProperty -Path $regPath -Name "Debugger" -ErrorAction SilentlyContinue

        if ($debugger) {

            Write-Host "UNBLOCKING: $exeName" -ForegroundColor Green
            Write-Log "Unblocking $exeName"

            Remove-ItemProperty -Path $regPath -Name "Debugger" -Force

            $remaining = Get-Item -Path $regPath | Select-Object -ExpandProperty Property

            if ($remaining.Count -eq 0) {
                Remove-Item -Path $regPath -Force
            }

            $unblockedExe += $exeName
        }
        else {
            Write-Host "No block found: $exeName" -ForegroundColor Yellow
            Write-Log "No debugger found for $exeName"
        }

    }
    else {

        Write-Host "Registry entry not found: $exeName" -ForegroundColor Red
        Write-Log "Registry entry not found for $exeName"

        $notFoundApps += $exeName
    }
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "              SUMMARY                   " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($unblockedExe.Count -gt 0) {

    Write-Host "`nApps Unblocked:" -ForegroundColor Yellow
    $unblockedExe | ForEach-Object { Write-Host " - $_" -ForegroundColor Green }
}

if ($notFoundApps.Count -gt 0) {

    Write-Host "`nApps Not Found:" -ForegroundColor Yellow
    $notFoundApps | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
}

Write-Host "`n---- Script Completed ----`n" -ForegroundColor Green
Write-Log "Script completed"