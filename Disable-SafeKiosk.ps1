#Requires -RunAsAdministrator

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       Safe Kiosk Mode Cleanup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This will completely remove the kiosk mode configuration." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Are you sure you want to continue? (YES/NO)"
if ($confirm -ne "YES") {
    Write-Host "Cleanup cancelled." -ForegroundColor Green
    exit
}

try {
    Write-Host "`nStarting cleanup..." -ForegroundColor Cyan
    
    # 1. Remove scheduled tasks
    Write-Host "Removing scheduled tasks..." -ForegroundColor Yellow
    Get-ScheduledTask -TaskName "Kiosk*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  Removing: $($_.TaskName)" -ForegroundColor White
        Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
    }
    Write-Host "  ✓ Scheduled tasks removed" -ForegroundColor Green
    
    # 2. Remove auto-login
    Write-Host "Removing auto-login..." -ForegroundColor Yellow
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultUsername" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "ForceAutoLogon" -ErrorAction SilentlyContinue
    Write-Host "  ✓ Auto-login removed" -ForegroundColor Green
    
    # 3. Remove startup items
    Write-Host "Removing startup items..." -ForegroundColor Yellow
    $startupItems = @(
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\KioskStartup.bat",
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\EmergencyHotkey.lnk"
    )
    
    foreach ($item in $startupItems) {
        if (Test-Path $item) {
            Remove-Item $item -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  ✓ Startup items removed" -ForegroundColor Green
    
    # 4. Remove kiosk user (optional)
    Write-Host "`nKiosk User Management:" -ForegroundColor Yellow
    Write-Host "The kiosk user account can be kept