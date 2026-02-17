# =====================================================
# WINDOWS LOCKDOWN REVERT / UNLOCK SCRIPT (COMPATIBLE)
# =====================================================

Write-Host "Reverting Windows lockdown..." -ForegroundColor Yellow

# -----------------------------------------------------
# ADMIN CHECK
# -----------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Error "Run this script as Administrator."
    exit 1
}

# -----------------------------------------------------
# 1. DISABLE APPLOCKER ENFORCEMENT
# -----------------------------------------------------
Write-Host "Disabling AppLocker enforcement..."

reg delete "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Exe" /v EnforcementMode /f 2>$null
reg delete "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Msi" /v EnforcementMode /f 2>$null
reg delete "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Script" /v EnforcementMode /f 2>$null

# -----------------------------------------------------
# 2. CLEAR APPLOCKER RULES (SAFE METHOD)
# -----------------------------------------------------
Write-Host "Clearing AppLocker rules..."

$emptyPolicy = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Msi" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Script" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Dll" EnforcementMode="NotConfigured" />
</AppLockerPolicy>
"@

$emptyPath = "$env:TEMP\AppLocker_Clear.xml"
$emptyPolicy | Out-File $emptyPath -Encoding utf8
Set-AppLockerPolicy -XmlPolicy $emptyPath 

# -----------------------------------------------------
# 3. RESTORE WINDOWS INSTALLER
# -----------------------------------------------------
Write-Host "Re-enabling Windows Installer..."
reg delete "HKCU\Software\Policies\Microsoft\Windows\Installer" /v DisableMSI /f 2>$null

# -----------------------------------------------------
# 4. RESTORE UNINSTALL UI
# -----------------------------------------------------
Write-Host "Restoring uninstall UI..."

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Uninstall" `
    /v NoAddRemovePrograms /f 2>$null

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    /v NoControlPanel /f 2>$null

# -----------------------------------------------------
# 5. RESTORE SYSTEM TOOLS
# -----------------------------------------------------
Write-Host "Restoring system tools..."

# CMD
reg delete "HKCU\Software\Policies\Microsoft\Windows\System" `
    /v DisableCMD /f 2>$null

# Task Manager
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    /v DisableTaskMgr /f 2>$null

# -----------------------------------------------------
# 6. RESTORE POWERSHELL SCRIPT EXECUTION
# -----------------------------------------------------
Write-Host "Restoring PowerShell execution..."
reg delete "HKLM\Software\Policies\Microsoft\Windows\PowerShell" `
    /v EnableScripts /f 2>$null

# -----------------------------------------------------
# 7. OPTIONAL: STOP APPIDSVC
# -----------------------------------------------------
Write-Host "Stopping Application Identity service..."
sc.exe stop AppIDSvc | Out-Null

# -----------------------------------------------------
# 8. APPLY CHANGES
# -----------------------------------------------------
Write-Host "Applying policy changes..."
gpupdate /force

Write-Host "UNLOCK COMPLETE REBOOT RECOMMENDED" -ForegroundColor Green
