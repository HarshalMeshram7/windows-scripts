# ============================================
# Remove Kiosk Mode - SafeBrowser
# Run as Administrator
# ============================================

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator."
    exit 1
}

# Check if kiosk is configured
Write-Host "Checking kiosk configuration..." -ForegroundColor Cyan
$existing = Get-AssignedAccess -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "No kiosk mode is currently configured. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "Kiosk configuration found:" -ForegroundColor Cyan
$existing | Format-List

# Confirm removal
$confirm = Read-Host "Are you sure you want to remove kiosk mode? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Aborted. No changes made." -ForegroundColor Yellow
    exit 0
}

# Step 1: Clear Assigned Access
Write-Host "`nRemoving Assigned Access..." -ForegroundColor Cyan
try {
    Clear-AssignedAccess
    Write-Host "Assigned Access cleared successfully!" -ForegroundColor Green
} catch {
    Write-Warning "Failed to clear Assigned Access: $_"
}

# Step 2: Restore default Windows Shell
Write-Host "`nRestoring default Windows shell..." -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -Value "explorer.exe" -Type String
    Write-Host "Shell restored to explorer.exe" -ForegroundColor Green
} catch {
    Write-Warning "Failed to restore shell: $_"
}

# Step 3: Verify removal
Write-Host "`nVerifying kiosk removal..." -ForegroundColor Cyan
$check = Get-AssignedAccess -ErrorAction SilentlyContinue
if (-not $check) {
    Write-Host "Confirmed: Kiosk mode has been removed successfully." -ForegroundColor Green
} else {
    Write-Warning "Kiosk mode may still be active. Please check manually."
}

# Step 4: Restart prompt
$restart = Read-Host "`nRestart now to apply changes? (y/n)"
if ($restart -eq "y") {
    Write-Host "Restarting..." -ForegroundColor Cyan
    Restart-Computer
} else {
    Write-Host "Please restart manually for changes to take effect." -ForegroundColor Yellow
}