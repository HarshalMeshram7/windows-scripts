# ============================================
# BULLETPROOF KIOSK DISABLE + FORCED REBOOT
# (Survives process filters & shell lockdown)
# ============================================

#Requires -RunAsAdministrator

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$kioskDir     = "C:\ProgramData\ChromePowerShellKiosk"
$taskName     = "ForceRebootAfterKioskDisable"

# --------------------------------------------
# 1. Restore Explorer Shell
# --------------------------------------------
$backupShell = (Get-ItemProperty $winlogonPath -Name Shell_Backup -ErrorAction SilentlyContinue).Shell_Backup

if ($backupShell) {
    Set-ItemProperty $winlogonPath -Name Shell -Value $backupShell -Force
    Remove-ItemProperty $winlogonPath -Name Shell_Backup -ErrorAction SilentlyContinue
} else {
    Set-ItemProperty $winlogonPath -Name Shell -Value "explorer.exe" -Force
}

# --------------------------------------------
# 2. Disable Auto-Login
# --------------------------------------------
"AutoAdminLogon","DefaultUsername","DefaultPassword","ForceAutoLogon" | ForEach-Object {
    Remove-ItemProperty $winlogonPath -Name $_ -ErrorAction SilentlyContinue
}

# --------------------------------------------
# 3. Remove Kiosk Scheduled Task
# --------------------------------------------
Unregister-ScheduledTask -TaskName "KioskProcessFilter" -Confirm:$false -ErrorAction SilentlyContinue

# --------------------------------------------
# 4. Restore Policies
# --------------------------------------------
Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name DisableTaskMgr -ErrorAction SilentlyContinue

Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name DontDisplayLastUserName -ErrorAction SilentlyContinue

Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" `
    -Name NoLockScreen -ErrorAction SilentlyContinue

Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -Name NoWinKeys -ErrorAction SilentlyContinue

# --------------------------------------------
# 5. Delete Kiosk Files
# --------------------------------------------
if (Test-Path $kioskDir) {
    Remove-Item $kioskDir -Recurse -Force
}

# --------------------------------------------
# 6. CREATE SYSTEM REBOOT TASK (UNKILLABLE)
# --------------------------------------------
$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /f /t 0"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Force | Out-Null

# --------------------------------------------
# 7. START TASK AND EXIT
# --------------------------------------------
Start-ScheduledTask -TaskName $taskName
exit
