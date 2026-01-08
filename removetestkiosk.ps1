# =====================================================
# DISABLE KIOSK MODE (LOCAL ONLY)
# =====================================================

$KioskUser = "KioskUser"

# -----------------------------------------------------
# 1. Remove Assigned Access
# -----------------------------------------------------
$CSPPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\AssignedAccess"
Remove-ItemProperty `
    -Path $CSPPath `
    -Name "Configuration" `
    -ErrorAction SilentlyContinue

# -----------------------------------------------------
# 2. Remove IFEO blocks
# -----------------------------------------------------
$IFEOBase = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

Get-ChildItem $IFEOBase -ErrorAction SilentlyContinue |
Where-Object {
    $_.PSChildName -in @(
        "powershell.exe",
        "cmd.exe",
        "taskmgr.exe",
        "regedit.exe",
        "control.exe",
        "mmc.exe"
    )
} | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# -----------------------------------------------------
# 3. Log off kiosk user
# -----------------------------------------------------
try {
    (quser | Where-Object { $_ -match $KioskUser }) |
    ForEach-Object {
        logoff (($_ -split '\s+')[2]) /f
    }
} catch {}

# -----------------------------------------------------
# 4. Remove kiosk profile
# -----------------------------------------------------
Get-CimInstance Win32_UserProfile |
Where-Object { $_.LocalPath -like "*\$KioskUser" } |
Remove-CimInstance -ErrorAction SilentlyContinue

# -----------------------------------------------------
# 5. Remove kiosk user
# -----------------------------------------------------
Remove-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue

Write-Output "Kiosk DISABLED. Reboot required."
shutdown /r /t 0
