# ============================================
# SIMPLE SAFE Kiosk Mode
# Chrome + Edge + VS Code + File Explorer + PowerShell
# ============================================

#Requires -RunAsAdministrator

param(
    [string]$KioskUser = "SafeKiosk",
    [string]$KioskPassword = "SafePass123",
    [string]$ChromeWebsite = "https://www.google.com"
)

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting SAFE Kiosk Mode Configuration..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ============================================
# 1. Create Kiosk User Account
# ============================================
Write-Host "Creating kiosk user account..." -ForegroundColor Yellow
$userExists = Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue

if (-not $userExists) {
    $securePassword = ConvertTo-SecureString $KioskPassword -AsPlainText -Force
    New-LocalUser -Name $KioskUser -Password $securePassword `
        -FullName "Safe Kiosk User" `
        -Description "Multi-App Kiosk with Escape Methods" `
        -AccountNeverExpires
    Write-Host "  ✓ Created kiosk user: $KioskUser" -ForegroundColor Green
} else {
    Write-Host "  ✓ Kiosk user already exists" -ForegroundColor Green
}

# ============================================
# 2. Create Kiosk Directory
# ============================================
Write-Host "Creating kiosk management directory..." -ForegroundColor Yellow
$kioskDir = "C:\ProgramData\SafeKiosk"
if (-not (Test-Path $kioskDir)) {
    New-Item -ItemType Directory -Path $kioskDir -Force | Out-Null
    Write-Host "  ✓ Created directory: $kioskDir" -ForegroundColor Green
} else {
    Write-Host "  ✓ Directory already exists" -ForegroundColor Green
}

# ============================================
# 3. Create Desktop Shortcuts
# ============================================
Write-Host "Creating desktop shortcuts..." -ForegroundColor Yellow

# Create user's desktop directory if it doesn't exist
$userDesktop = "C:\Users\$KioskUser\Desktop"
if (-not (Test-Path $userDesktop)) {
    New-Item -ItemType Directory -Path $userDesktop -Force | Out-Null
}

# Create Allowed Applications folder on desktop
$appsFolder = "$userDesktop\Allowed Applications"
if (-not (Test-Path $appsFolder)) {
    New-Item -ItemType Directory -Path $appsFolder -Force | Out-Null
}

# Create shortcuts using WScript.Shell
$wshShell = New-Object -ComObject WScript.Shell

# 1. Chrome shortcut (with kiosk mode)
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    $shortcut = $wshShell.CreateShortcut("$appsFolder\Google Chrome.lnk")
    $shortcut.TargetPath = $chromePath
    $shortcut.Arguments = "--kiosk --fullscreen $ChromeWebsite"
    $shortcut.WorkingDirectory = (Split-Path $chromePath)
    $shortcut.Save()
    Write-Host "  ✓ Created Chrome shortcut" -ForegroundColor Green
}

# 2. Edge shortcut
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edgePath)) { 
    $edgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" 
}
if (Test-Path $edgePath) {
    $shortcut = $wshShell.CreateShortcut("$appsFolder\Microsoft Edge.lnk")
    $shortcut.TargetPath = $edgePath
    $shortcut.WorkingDirectory = (Split-Path $edgePath)
    $shortcut.Save()
    Write-Host "  ✓ Created Edge shortcut" -ForegroundColor Green
}

# 3. VS Code shortcut
$vscodePaths = @(
    "C:\Users\$KioskUser\AppData\Local\Programs\Microsoft VS Code\Code.exe",
    "C:\Program Files\Microsoft VS Code\Code.exe",
    "C:\Program Files (x86)\Microsoft VS Code\Code.exe"
)

foreach ($path in $vscodePaths) {
    if (Test-Path $path) {
        $shortcut = $wshShell.CreateShortcut("$appsFolder\Visual Studio Code.lnk")
        $shortcut.TargetPath = $path
        $shortcut.WorkingDirectory = "C:\"
        $shortcut.Save()
        Write-Host "  ✓ Created VS Code shortcut" -ForegroundColor Green
        break
    }
}

# 4. File Explorer shortcut
$shortcut = $wshShell.CreateShortcut("$appsFolder\File Explorer.lnk")
$shortcut.TargetPath = "explorer.exe"
$shortcut.Save()
Write-Host "  ✓ Created File Explorer shortcut" -ForegroundColor Green

# 5. PowerShell shortcut
$shortcut = $wshShell.CreateShortcut("$appsFolder\PowerShell.lnk")
$shortcut.TargetPath = "powershell.exe"
$shortcut.WorkingDirectory = "C:\"
$shortcut.Save()
Write-Host "  ✓ Created PowerShell shortcut" -ForegroundColor Green

# 6. Command Prompt shortcut
$shortcut = $wshShell.CreateShortcut("$appsFolder\Command Prompt.lnk")
$shortcut.TargetPath = "cmd.exe"
$shortcut.WorkingDirectory = "C:\"
$shortcut.Save()
Write-Host "  ✓ Created Command Prompt shortcut" -ForegroundColor Green

# 7. Notepad shortcut
$shortcut = $wshShell.CreateShortcut("$appsFolder\Notepad.lnk")
$shortcut.TargetPath = "notepad.exe"
$shortcut.Save()
Write-Host "  ✓ Created Notepad shortcut" -ForegroundColor Green

# 8. Task Manager shortcut
$shortcut = $wshShell.CreateShortcut("$appsFolder\Task Manager.lnk")
$shortcut.TargetPath = "taskmgr.exe"
$shortcut.Save()
Write-Host "  ✓ Created Task Manager shortcut" -ForegroundColor Green

# 9. Exit Kiosk shortcut
$shortcut = $wshShell.CreateShortcut("$userDesktop\Exit Kiosk Mode.lnk")
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File `"C:\ProgramData\SafeKiosk\ExitKiosk.ps1`""
$shortcut.WorkingDirectory = "C:\"
$shortcut.Save()
Write-Host "  ✓ Created Exit Kiosk shortcut" -ForegroundColor Green

# ============================================
# 4. Create Exit Scripts
# ============================================
Write-Host "Creating exit scripts..." -ForegroundColor Yellow

# PowerShell exit script
$exitScript = @'
Write-Host "============================================" -ForegroundColor Red
Write-Host "        EXITING KIOSK MODE" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will disable kiosk mode features." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Are you sure? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "Exit cancelled." -ForegroundColor Green
    pause
    exit
}

Write-Host "`nDisabling kiosk mode..." -ForegroundColor Yellow

# Remove startup script
$startupScript = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\KioskStartup.bat"
if (Test-Path $startupScript) {
    Remove-Item $startupScript -Force
    Write-Host "  ✓ Removed startup script" -ForegroundColor Green
}

# Remove scheduled task
$taskName = "KioskAppMonitor"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  ✓ Removed scheduled task" -ForegroundColor Green
}

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "KIOSK MODE DISABLED!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Changes will take effect after restart." -ForegroundColor Yellow
Write-Host ""

$restart = Read-Host "Restart now? (Y/N)"
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Restart-Computer -Force
} else {
    Write-Host "Please restart manually when ready." -ForegroundColor Yellow
    pause
}
'@

$exitScript | Out-File -FilePath "$kioskDir\ExitKiosk.ps1" -Encoding UTF8
Write-Host "  ✓ Created exit script" -ForegroundColor Green

# ============================================
# 5. Create Startup Script
# ============================================
Write-Host "Creating startup script..." -ForegroundColor Yellow

$startupDir = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
$startupBatch = @'
@echo off
echo Starting Kiosk Mode...
echo.

:: Wait for Windows to fully start
timeout /t 5 /nobreak >nul

:: Start Chrome in kiosk mode
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk --fullscreen https://www.google.com
    echo Chrome started in kiosk mode
) else (
    echo Chrome not found
)

:: Create a simple monitor to log activity
powershell -WindowStyle Hidden -Command "& {
    `$logFile = 'C:\ProgramData\SafeKiosk\kiosk.log'
    'Kiosk started at ' + (Get-Date) | Out-File `$logFile -Append
    while (`$true) {
        Start-Sleep -Seconds 30
        'Kiosk running at ' + (Get-Date) | Out-File `$logFile -Append
    }
}" >nul 2>&1

echo.
echo Kiosk mode is active.
echo Use Windows key to access other applications.
echo Check 'Allowed Applications' folder on Desktop.
pause
'@

$startupBatch | Out-File -FilePath "$startupDir\KioskStartup.bat" -Encoding ASCII
Write-Host "  ✓ Created startup script" -ForegroundColor Green

# ============================================
# 6. Create README File
# ============================================
Write-Host "Creating README file..." -ForegroundColor Yellow

$readme = @"
========================================
         SAFE KIOSK MODE
========================================

ALLOWED APPLICATIONS:
----------------------
1. Google Chrome (auto-starts in kiosk mode)
2. Microsoft Edge
3. Visual Studio Code
4. File Explorer
5. PowerShell
6. Command Prompt
7. Notepad
8. Task Manager

Access from: 'Allowed Applications' folder on Desktop

HOW TO USE:
-----------
- Chrome starts automatically in kiosk mode
- Press Windows key to access Start Menu
- Use Alt+Tab to switch between apps
- All Windows features are available

TO EXIT CHROME KIOSK:
---------------------
- Alt+F4 to close Chrome
- F11 to exit fullscreen
- Use Task Manager (Ctrl+Shift+Esc)

TO EXIT KIOSK MODE:
-------------------
1. Click 'Exit Kiosk Mode' shortcut on Desktop
2. Run C:\ProgramData\SafeKiosk\ExitKiosk.ps1
3. Restart in Safe Mode if needed

NO RESTRICTIONS APPLIED:
-----------------------
- Task Manager: ENABLED
- Windows Key: ENABLED
- Alt+Tab: ENABLED
- File Explorer: ENABLED

Files location: C:\ProgramData\SafeKiosk\
========================================
"@

$readme | Out-File -FilePath "$userDesktop\KIOSK_README.txt" -Encoding UTF8
$readme | Out-File -FilePath "$kioskDir\README.txt" -Encoding UTF8
Write-Host "  ✓ Created README files" -ForegroundColor Green

# ============================================
# 7. Configure Optional Auto-Login
# ============================================
Write-Host "`nAuto-Login Configuration (Optional):" -ForegroundColor Yellow
Write-Host "Auto-login makes it convenient but harder to exit." -ForegroundColor White
$enableAutoLogin = Read-Host "Enable auto-login? (Y/N - Recommended: N for safety)"

if ($enableAutoLogin -eq 'Y' -or $enableAutoLogin -eq 'y') {
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
    Set-ItemProperty -Path $registryPath -Name "DefaultUsername" -Value $KioskUser -Type String -Force
    Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value $KioskPassword -Type String -Force
    Write-Host "  ✓ Auto-login enabled" -ForegroundColor Green
    Write-Host "  WARNING: Password is stored in registry" -ForegroundColor Red
} else {
    Write-Host "  ✓ Auto-login disabled (safer)" -ForegroundColor Green
}

# ============================================
# 8. Final Configuration
# ============================================
Write-Host "`nApplying final configurations..." -ForegroundColor Yellow

# Ensure Task Manager is enabled
$policiesPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $policiesPath)) {
    New-Item -Path $policiesPath -Force | Out-Null
}
Set-ItemProperty -Path $policiesPath -Name "DisableTaskMgr" -Value 0 -Type DWord -Force
Write-Host "  ✓ Task Manager enabled" -ForegroundColor Green

# Configure power settings
powercfg -change -monitor-timeout-ac 30
powercfg -change -standby-timeout-ac 60
Write-Host "  ✓ Power settings configured" -ForegroundColor Green

# ============================================
# 9. Summary
# ============================================
Write-Host "`n" + "="*50 -ForegroundColor Green
Write-Host "       SAFE KIOSK MODE CONFIGURED!" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Green
Write-Host ""
Write-Host "USER ACCOUNT:" -ForegroundColor Yellow
Write-Host "  Username: $KioskUser" -ForegroundColor White
Write-Host "  Password: $KioskPassword" -ForegroundColor White
Write-Host ""
Write-Host "ALLOWED APPLICATIONS (8 total):" -ForegroundColor Yellow
Write-Host "  • Google Chrome (auto-starts in kiosk)" -ForegroundColor Cyan
Write-Host "  • Microsoft Edge" -ForegroundColor Cyan
Write-Host "  • Visual Studio Code" -ForegroundColor Cyan
Write-Host "  • File Explorer" -ForegroundColor Cyan
Write-Host "  • PowerShell" -ForegroundColor Cyan
Write-Host "  • Command Prompt" -ForegroundColor Cyan
Write-Host "  • Notepad" -ForegroundColor Cyan
Write-Host "  • Task Manager" -ForegroundColor Cyan
Write-Host ""
Write-Host "ACCESS METHODS:" -ForegroundColor Yellow
Write-Host "  • Windows key (Start Menu)" -ForegroundColor White
Write-Host "  • Alt+Tab (switch apps)" -ForegroundColor White
Write-Host "  • Desktop shortcuts in 'Allowed Applications' folder" -ForegroundColor White
Write-Host ""
Write-Host "EMERGENCY EXIT:" -ForegroundColor Yellow
Write-Host "  1. Desktop shortcut: 'Exit Kiosk Mode'" -ForegroundColor White
Write-Host "  2. Run: C:\ProgramData\SafeKiosk\ExitKiosk.ps1" -ForegroundColor White
Write-Host "  3. Restart in Safe Mode (if needed)" -ForegroundColor White
Write-Host ""
Write-Host "FILES LOCATION:" -ForegroundColor Yellow
Write-Host "  C:\ProgramData\SafeKiosk\" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Green

# ============================================
# 10. Testing Instructions
# ============================================
Write-Host "`nTESTING INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "---------------------" -ForegroundColor Yellow
Write-Host "1. Sign out from current user (Start > User icon > Sign out)" -ForegroundColor White
Write-Host "2. Login as: $KioskUser" -ForegroundColor White
Write-Host "3. Password: $KioskPassword" -ForegroundColor White
Write-Host "4. Chrome will auto-start in kiosk mode" -ForegroundColor White
Write-Host "5. Test all applications work" -ForegroundColor White
Write-Host "6. Test exit methods work" -ForegroundColor White
Write-Host ""

$testNow = Read-Host "Switch to kiosk user now? (Y/N)"
if ($testNow -eq 'Y' -or $testNow -eq 'y') {
    Write-Host "Switching to kiosk user..." -ForegroundColor Cyan
    # Create a simple script to switch user
    $switchScript = @"
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show('Please sign out and login as $KioskUser to test kiosk mode.', 'Kiosk Mode Ready', 'OK', 'Information')
"@
    $switchScript | Out-File -FilePath "$env:TEMP\SwitchUser.ps1" -Encoding UTF8
    powershell -ExecutionPolicy Bypass -File "$env:TEMP\SwitchUser.ps1"
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green