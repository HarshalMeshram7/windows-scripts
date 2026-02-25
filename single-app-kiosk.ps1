# ==========================================
# Edge Soft Kiosk (Any Windows Version)
# ==========================================

$KioskUser = "kioskuser"
$EdgePath  = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$KioskUrl  = "https://www.google.com"

# Create user if missing
if (-not (Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue)) {
    net user $KioskUser /add
}

# Replace shell for kiosk user
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $RegPath -Name Shell `
 -Value "`"$EdgePath`" --kiosk $KioskUrl --edge-kiosk-type=fullscreen --no-first-run"

# Disable Task Manager
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Force | Out-Null
Set-ItemProperty `
 -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
 -Name DisableTaskMgr -Value 1 -Type DWord

Write-Host "Edge soft kiosk configured."
Write-Host "Restart and log in as $KioskUser"