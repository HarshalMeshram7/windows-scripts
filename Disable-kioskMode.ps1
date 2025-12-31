#Requires -RunAsAdministrator

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Chrome + PowerShell Kiosk Mode Cleanup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Confirm user wants to proceed
Write-Host "WARNING: This will restore normal Windows functionality." -ForegroundColor Yellow
Write-Host "The kiosk mode will be disabled and system will return to normal." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Are you sure you want to continue? (Y/N)"

if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "Cleanup cancelled." -ForegroundColor Green
    exit
}

try {
    Write-Host "Starting cleanup process..." -ForegroundColor Cyan
    
    # 1. Restore original shell
    Write-Host "Restoring Windows Shell..." -ForegroundColor Yellow
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $backupShell = (Get-ItemProperty -Path $regPath -Name "Shell_Backup" -ErrorAction SilentlyContinue).Shell_Backup
    
    if ($backupShell) {
        Set-ItemProperty -Path $regPath -Name "Shell" -Value $backupShell -Force
        Remove-ItemProperty -Path $regPath -Name "Shell_Backup" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Restored shell: $backupShell" -ForegroundColor Green
    } else {
        Set-ItemProperty -Path $regPath -Name "Shell" -Value "explorer.exe" -Force
        Write-Host "  ✓ Restored default shell: explorer.exe" -ForegroundColor Green
    }
    
    # 2. Remove auto-login
    Write-Host "Removing auto-login..." -ForegroundColor Yellow
    Remove-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultUsername" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "ForceAutoLogon" -ErrorAction SilentlyContinue
    Write-Host "  ✓ Auto-login disabled" -ForegroundColor Green
    
    # 3. Remove scheduled task
    Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName "KioskProcessFilter" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  ✓ Removed process filter task" -ForegroundColor Green
    
    # 4. Remove system restrictions
    Write-Host "Removing system restrictions..." -ForegroundColor Yellow
    
    # Task Manager
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
    
    # Login screen
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DontDisplayLastUserName" -ErrorAction SilentlyContinue
    
    # Lock screen
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -ErrorAction SilentlyContinue
    
    # Windows key
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys" -ErrorAction SilentlyContinue
    
    Write-Host "  ✓ System restrictions removed" -ForegroundColor Green
    
    # 5. Clean up kiosk files (optional - keep for debugging)
    Write-Host "Cleaning up kiosk files..." -ForegroundColor Yellow
    $kioskDir = "C:\ProgramData\ChromePowerShellKiosk"
    if (Test-Path $kioskDir) {
        # Don't delete logs - keep for debugging
        Write-Host "  ✓ Kiosk files kept at: $kioskDir" -ForegroundColor Green
    }
    
    # 6. Reset power settings
    Write-Host "Resetting power settings..." -ForegroundColor Yellow
    powercfg -change -standby-timeout-ac 10
    powercfg -change -monitor-timeout-ac 15
    Write-Host "  ✓ Power settings restored" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "CLEANUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Normal Windows functionality has been restored." -ForegroundColor Yellow
    Write-Host "The system will now behave like a standard Windows installation." -ForegroundColor Yellow
    Write-Host ""
    
    $restart = Read-Host "Restart now to apply all changes? (Y/N)"
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Write-Host "Restarting computer..." -ForegroundColor Cyan
        Restart-Computer -Force
    }
    
}
catch {
    Write-Host "Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}