# ==========================================
# ROLLBACK SCRIPT
# Disable Multi-App Kiosk Mode
# Remove Kiosk User
# ==========================================

$KioskUser = "KioskUser"

Write-Output "🔄 Starting kiosk rollback..."

# ------------------------------------------
# 1. Remove Assigned Access CSP configuration
# ------------------------------------------
$CSPPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\AssignedAccess"

if (Test-Path $CSPPath) {
    Remove-ItemProperty `
        -Path $CSPPath `
        -Name "Configuration" `
        -ErrorAction SilentlyContinue

    Write-Output "✅ Kiosk configuration removed."
}
else {
    Write-Output "ℹ️ AssignedAccess CSP not found."
}

# ------------------------------------------
# 2. Log off kiosk user if currently logged in
# ------------------------------------------
try {
    $sessions = (quser 2>$null) -match $KioskUser
    if ($sessions) {
        $sessions | ForEach-Object {
            $sessionId = ($_ -split '\s+')[2]
            logoff $sessionId /f
        }
        Write-Output "✅ Kiosk user logged off."
    }
}
catch {
    Write-Output "⚠️ Unable to determine kiosk user session."
}

# ------------------------------------------
# 3. Remove Kiosk User Account
# ------------------------------------------
if (Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue) {

    Remove-LocalUser -Name $KioskUser
    Write-Output "✅ Kiosk user account removed."
}
else {
    Write-Output "ℹ️ Kiosk user does not exist."
}

# ------------------------------------------
# 4. Optional: Remove AssignedAccess cache
# ------------------------------------------
$CachePath = "HKLM:\SOFTWARE\Microsoft\AssignedAccess"
if (Test-Path $CachePath) {
    Remove-Item -Path $CachePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "✅ AssignedAccess cache cleared."
}

Write-Output "✅ Kiosk rollback completed. Restart required."
shutdown /r /t 10
