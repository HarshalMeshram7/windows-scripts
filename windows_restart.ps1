# ============================================================
# Force Restart Script with Logger
# Log Location: C:\Logs\restart.log
# ============================================================

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\restart.log"

# --- Ensure log directory exists ---
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# --- Logger function ---
function Write-Log {
    param (
        [string]$Level,
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry     = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $Entry
    Write-Host $Entry
}

# --- Main ---
Write-Log "INFO"  "Script started by user: $env:USERNAME on host: $env:COMPUTERNAME"
Write-Log "INFO"  "Initiating forced restart..."

try {
    shutdown /r /t 0 /f
    Write-Log "INFO" "Shutdown command issued successfully."
} catch {
    Write-Log "ERROR" "Failed to issue shutdown command: $_"
    exit 1
}