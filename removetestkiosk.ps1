# =====================================================
# DISABLE / ROLLBACK KIOSK MODE (FULL CLEANUP)
# =====================================================

$KioskUser = "KioskUser"

Write-Output "Starting kiosk rollback..."

# -----------------------------------------------------
# 1. Remove Assigned Access CSP
# -----------------------------------------------------
$CSPPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\AssignedAccess"

if (Test-Path $CSPPath) {
    Remove-ItemProperty `
        -Path $CSPPath `
        -Name "Configuration" `
        -ErrorAction SilentlyContinue

    Write-Output "Assigned Access CSP removed."
}

# -----------------------------------------------------
# 2. Remove IFEO blocks (restore CMD/PS/TaskMgr/etc)
# -----------------------------------------------------
$BlockedApps = @(
    "powershell.exe",
    "cmd.exe",
    "regedit.exe",
    "taskmgr.exe",
    "control.exe",
    "mmc.exe"
)

foreach ($app in $BlockedApps) {
    $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$app"
    if (Test-Path $ifeoPath) {
        Remove-Item -Path $ifeoPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "Blocked system tools restored."

# -----------------------------------------------------
# 3. Log off kiosk user if logged in
# -----------------------------------------------------
try {
    $sessions = (quser 2>$null) -match $KioskUser
    if ($sessions) {
        $sessions | ForEach-Object {
            $sessionId = ($_ -split '\s+')[2]
            logoff $sessionId /f
        }
        Write-Output "Kiosk user logged off."
    }
}
catch {}

# -----------------------------------------------------
# 4. Remove kiosk user profile
# -----------------------------------------------------
$profile = Get-CimInstance Win32_UserProfile |
    Where-Object { $_.LocalPath -like "*\$KioskUser" }

if ($profile) {
    $profile | Remove-CimInstance
    Write-Output "Kiosk user profile removed."
}

# -----------------------------------------------------
# 5. Remove kiosk user account
# -----------------------------------------------------
if (Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $KioskUser
    Write-Output "Kiosk user account removed."
}

# -----------------------------------------------------
# 6. Clear Assigned Access cache (optional but recommended)
# -----------------------------------------------------
$CachePath = "HKLM:\SOFTWARE\Microsoft\AssignedAccess"
if (Test-Path $CachePath) {
    Remove-Item -Path $CachePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "Assigned Access cache cleared."
}

Write-Output "Kiosk mode fully disabled. REBOOT REQUIRED."
shutdown /r /t 0
