#Requires -RunAsAdministrator

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Chrome + PowerShell Kiosk Mode Cleanup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Restoring normal Windows functionality..." -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Starting cleanup process..." -ForegroundColor Cyan

    # --------------------------------------------------
    # 1. Restore Windows shell
    # --------------------------------------------------
    Write-Host "Restoring Windows shell..." -ForegroundColor Yellow

    $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $shellBackup  = (Get-ItemProperty -Path $winlogonPath -Name "Shell_Backup" -ErrorAction SilentlyContinue).Shell_Backup

    if ($shellBackup) {
        Set-ItemProperty -Path $winlogonPath -Name "Shell" -Value $shellBackup -Force
        Remove-ItemProperty -Path $winlogonPath -Name "Shell_Backup" -ErrorAction SilentlyContinue
        Write-Host "  Shell restored from backup" -ForegroundColor Green
    }
    else {
        Set-ItemProperty -Path $winlogonPath -Name "Shell" -Value "explorer.exe" -Force
        Write-Host "  Shell set to explorer.exe" -ForegroundColor Green
    }

    # --------------------------------------------------
    # 2. Disable auto-login
    # --------------------------------------------------
    Write-Host "Disabling auto-login..." -ForegroundColor Yellow

    foreach ($key in @(
        "AutoAdminLogon",
        "DefaultUsername",
        "DefaultPassword",
        "ForceAutoLogon"
    )) {
        Remove-ItemProperty -Path $winlogonPath -Name $key -ErrorAction SilentlyContinue
    }

    Write-Host "  Auto-login disabled" -ForegroundColor Green

    # --------------------------------------------------
    # 3. Remove scheduled task
    # --------------------------------------------------
    Write-Host "Removing kiosk scheduled task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName "KioskProcessFilter" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  Scheduled task removed" -ForegroundColor Green

    # --------------------------------------------------
    # 4. Remove system restrictions
    # --------------------------------------------------
    Write-Host "Removing system restrictions..." -ForegroundColor Yellow

    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DontDisplayLastUserName" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys" -ErrorAction SilentlyContinue

    Write-Host "  Restrictions removed" -ForegroundColor Green

    # --------------------------------------------------
    # 5. Reset power settings
    # --------------------------------------------------
    Write-Host "Resetting power settings..." -ForegroundColor Yellow
    powercfg -change -standby-timeout-ac 10 | Out-Null
    powercfg -change -monitor-timeout-ac 15 | Out-Null
    Write-Host "  Power settings restored" -ForegroundColor Green

    # --------------------------------------------------
    # Finish + auto restart
    # --------------------------------------------------
    Write-Host ""
    Write-Host "Cleanup completed successfully." -ForegroundColor Green
    Write-Host "System will restart automatically in 5 seconds..." -ForegroundColor Yellow

    Start-Sleep -Seconds 2
    Restart-Computer -Force
}
catch {
    Write-Host ""
    Write-Host "ERROR during cleanup:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
