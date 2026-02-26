# ============================================
# Apply Kiosk Mode - SafeBrowser
# Run as Administrator
# ============================================

# ---------- CONFIGURATION ----------
$KioskUser  = "kioskuser"                                       # Change to your username
$KioskAUMID = "com.safe4sure.SafeBrowser_fpmp3vg97j7wc!App"   # SafeBrowser AUMID
# -----------------------------------

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator."
    exit 1
}

# Verify user exists
Write-Host "Checking user '$KioskUser'..." -ForegroundColor Cyan
$user = Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Error "User '$KioskUser' not found. Please check the username."
    exit 1
}
Write-Host "User '$KioskUser' found." -ForegroundColor Green

# Verify SafeBrowser is installed
Write-Host "`nChecking if SafeBrowser is installed..." -ForegroundColor Cyan
$app = Get-AppxPackage -AllUsers | Where-Object { $_.PackageFamilyName -like "*fpmp3vg97j7wc*" }
if (-not $app) {
    Write-Error "SafeBrowser not found. Please install it before applying kiosk mode."
    exit 1
}
Write-Host "SafeBrowser found: $($app.Name) v$($app.Version)" -ForegroundColor Green

# Check if kiosk already configured
Write-Host "`nChecking existing kiosk configuration..." -ForegroundColor Cyan
$existing = Get-AssignedAccess -ErrorAction SilentlyContinue
if ($existing) {
    Write-Warning "Kiosk mode is already configured:"
    $existing | Format-List
    $overwrite = Read-Host "Do you want to overwrite it? (y/n)"
    if ($overwrite -ne "y") {
        Write-Host "Aborted. No changes made." -ForegroundColor Yellow
        exit 0
    }
    # Clear existing before reapplying
    Clear-AssignedAccess
    Write-Host "Existing kiosk cleared." -ForegroundColor Yellow
}

# Apply Kiosk Mode
Write-Host "`nApplying kiosk mode for user '$KioskUser'..." -ForegroundColor Cyan
try {
    Set-AssignedAccess -UserName $KioskUser -AppUserModelId $KioskAUMID
    Write-Host "Kiosk mode applied successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to apply kiosk mode: $_"
    exit 1
}

# Verify
Write-Host "`nVerifying configuration..." -ForegroundColor Cyan
$verify = Get-AssignedAccess
if ($verify) {
    Write-Host "Confirmed kiosk configuration:" -ForegroundColor Green
    $verify | Format-List
} else {
    Write-Warning "Could not verify kiosk configuration. Please check manually."
}

# Restart prompt
$restart = Read-Host "`nRestart now to apply changes? (y/n)"
if ($restart -eq "y") {
    Write-Host "Restarting..." -ForegroundColor Cyan
    Restart-Computer
} else {
    Write-Host "Please restart manually for changes to take effect." -ForegroundColor Yellow
}