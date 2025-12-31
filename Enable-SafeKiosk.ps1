# ============================================
# SAFE Kiosk Mode with Multiple Apps & Escape Methods
# ============================================

#Requires -RunAsAdministrator

param(
    [string]$KioskUser = "SafeKiosk",
    [string]$KioskPassword = "SafePass123",
    [string]$ChromeWebsite = "https://www.google.com"
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Cyan
    Add-Content -Path "C:\KioskSetup.log" -Value "[$timestamp] $Message"
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Log "Starting SAFE Kiosk Mode Configuration..."

try {
    # ============================================
    # 1. Create Kiosk User Account
    # ============================================
    Write-Log "Creating kiosk user account..."
    
    $userExists = Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue
    
    if (-not $userExists) {
        $securePassword = ConvertTo-SecureString $KioskPassword -AsPlainText -Force
        New-LocalUser -Name $KioskUser -Password $securePassword `
            -FullName "Safe Kiosk User" `
            -Description "Multi-App Kiosk with Escape Methods" `
            -AccountNeverExpires
        Write-Log "Created kiosk user: $KioskUser"
    } else {
        Write-Log "Kiosk user already exists"
    }
    
    # ============================================
    # 2. Create Kiosk Management Directory
    # ============================================
    Write-Log "Creating kiosk management directory..."
    
    $kioskDir = "C:\ProgramData\SafeKiosk"
    if (-not (Test-Path $kioskDir)) {
        New-Item -ItemType Directory -Path $kioskDir -Force | Out-Null
    }
    
    # ============================================
    # 3. Create SAFE Launcher (with Taskbar & Start Menu)
    # ============================================
    Write-Log "Creating safe launcher with full Windows shell..."
    
    $launcherScript = @'
# Safe Kiosk Mode Launcher
# This runs WITH Windows Explorer (not as replacement)

# Create Control Panel on desktop for easy exit
$desktopPath = [Environment]::GetFolderPath("Desktop")
$controlPanelPath = "$desktopPath\Kiosk Control Panel.lnk"
$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($controlPanelPath)
$shortcut.TargetPath = "control.exe"
$shortcut.Save()

# Create Exit Kiosk shortcut
$exitShortcutPath = "$desktopPath\Exit Kiosk Mode.lnk"
$shortcut = $wshShell.CreateShortcut($exitShortcutPath)
$shortcut.TargetPath = "C:\ProgramData\SafeKiosk\ExitKiosk.bat"
$shortcut.Save()

# Create Allowed Applications folder on desktop
$appsFolder = "$desktopPath\Allowed Applications"
if (-not (Test-Path $appsFolder)) {
    New-Item -ItemType Directory -Path $appsFolder -Force | Out-Null
}

# Create application shortcuts
# Chrome
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    $shortcut = $wshShell.CreateShortcut("$appsFolder\Google Chrome.lnk")
    $shortcut.TargetPath = $chromePath
    $shortcut.Arguments = "--kiosk --fullscreen https://www.google.com"
    $shortcut.WorkingDirectory = (Split-Path $chromePath)
    $shortcut.Save()
}

# Edge
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edgePath)) { $edgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
if (Test-Path $edgePath) {
    $shortcut = $wshShell.CreateShortcut("$appsFolder\Microsoft Edge.lnk")
    $shortcut.TargetPath = $edgePath
    $shortcut.Arguments = "--kiosk --fullscreen"
    $shortcut.WorkingDirectory = (Split-Path $edgePath)
    $shortcut.Save()
}

# VS Code
$vscodePaths = @(
    "C:\Users\$env:USERNAME\AppData\Local\Programs\Microsoft VS Code\Code.exe",
    "C:\Program Files\Microsoft VS Code\Code.exe"
)
foreach ($path in $vscodePaths) {
    if (Test-Path $path) {
        $shortcut = $wshShell.CreateShortcut("$appsFolder\Visual Studio Code.lnk")
        $shortcut.TargetPath = $path
        $shortcut.WorkingDirectory = "C:\"
        $shortcut.Save()
        break
    }
}

# File Explorer
$shortcut = $wshShell.CreateShortcut("$appsFolder\File Explorer.lnk")
$shortcut.TargetPath = "explorer.exe"
$shortcut.Save()

# PowerShell
$shortcut = $wshShell.CreateShortcut("$appsFolder\PowerShell.lnk")
$shortcut.TargetPath = "powershell.exe"
$shortcut.Save()

# Command Prompt
$shortcut = $wshShell.CreateShortcut("$appsFolder\Command Prompt.lnk")
$shortcut.TargetPath = "cmd.exe"
$shortcut.Save()

# Notepad
$shortcut = $wshShell.CreateShortcut("$appsFolder\Notepad.lnk")
$shortcut.TargetPath = "notepad.exe"
$shortcut.Save()

# Task Manager (for emergencies)
$shortcut = $wshShell.CreateShortcut("$appsFolder\Task Manager.lnk")
$shortcut.TargetPath = "taskmgr.exe"
$shortcut.Save()

# Launch Chrome automatically on startup
Start-Sleep -Seconds 2
if (Test-Path $chromePath) {
    Start-Process $chromePath -ArgumentList "--kiosk --fullscreen https://www.google.com" -WindowStyle Maximized
}

# Show welcome message
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Kiosk Mode Active"
$form.Size = New-Object System.Drawing.Size(400,300)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(360,200)
$label.Text = @"
SAFE KIOSK MODE IS ACTIVE

Allowed Applications:
• Google Chrome (Auto-started in kiosk mode)
• Microsoft Edge
• Visual Studio Code
• File Explorer
• PowerShell
• Command Prompt
• Notepad
• Task Manager

To exit Chrome kiosk mode: Press Alt+F4

Emergency Exit Methods:
1. Use 'Exit Kiosk Mode' shortcut on desktop
2. Press Ctrl+Shift+E anywhere (3 times)
3. Run C:\ProgramData\SafeKiosk\EmergencyExit.bat

Desktop shortcuts are in 'Allowed Applications' folder.

Press OK to continue...
"@
$form.Controls.Add($label)

$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(150,220)
$button.Size = New-Object System.Drawing.Size(75,23)
$button.Text = "OK"
$button.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($button)

$form.Add_Shown({$form.Activate()})
$form.ShowDialog() | Out-Null
'@
    
    $launcherScript | Out-File -FilePath "$kioskDir\Launcher.ps1" -Encoding UTF8
    
    # ============================================
    # 4. Create MULTIPLE Emergency Exit Methods
    # ============================================
    Write-Log "Creating emergency exit methods..."
    
    # Exit Script 1: Simple batch file
    $exitScript1 = @'
@echo off
echo ========================================
echo     EXITING KIOSK MODE
echo ========================================
echo.
echo This will restore normal Windows operation.
echo.
echo WARNING: This will disable kiosk restrictions.
echo.
pause

REM Restore normal shell
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "explorer.exe" /f

REM Remove auto-login
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUsername /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f

REM Remove scheduled tasks
schtasks /delete /tn "KioskMonitor" /f
schtasks /delete /tn "KioskAppMonitor" /f

echo.
echo Kiosk mode has been disabled.
echo Please restart your computer for changes to take effect.
echo.
pause
'@
    
    $exitScript1 | Out-File -FilePath "$kioskDir\ExitKiosk.bat" -Encoding ASCII
    
    # Exit Script 2: Hotkey-based exit (Ctrl+Shift+E pressed 3 times)
    $exitScript2 = @'
using System;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;

namespace EmergencyExit
{
    class Program
    {
        [DllImport("user32.dll")]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);
        
        [DllImport("user32.dll")]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
        
        private const int MOD_CONTROL = 0x0002;
        private const int MOD_SHIFT = 0x0004;
        private const int WM_HOTKEY = 0x0312;
        private static int pressCount = 0;
        private static DateTime lastPress = DateTime.MinValue;
        
        static void Main()
        {
            Application.Run(new HotkeyForm());
        }
    }
    
    public class HotkeyForm : Form
    {
        public HotkeyForm()
        {
            this.WindowState = FormWindowState.Minimized;
            this.ShowInTaskbar = false;
            this.Opacity = 0;
            
            // Register Ctrl+Shift+E hotkey
            RegisterHotKey(this.Handle, 1, Program.MOD_CONTROL | Program.MOD_SHIFT, (int)Keys.E);
        }
        
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Program.WM_HOTKEY)
            {
                DateTime now = DateTime.Now;
                
                // Reset counter if more than 3 seconds between presses
                if ((now - Program.lastPress).TotalSeconds > 3)
                {
                    Program.pressCount = 0;
                }
                
                Program.pressCount++;
                Program.lastPress = now;
                
                // If pressed 3 times within 3 seconds
                if (Program.pressCount >= 3)
                {
                    // Launch exit script
                    Process.Start(@"C:\ProgramData\SafeKiosk\EmergencyExit.bat");
                    Program.pressCount = 0;
                }
            }
            
            base.WndProc(ref m);
        }
        
        protected override void Dispose(bool disposing)
        {
            UnregisterHotKey(this.Handle, 1);
            base.Dispose(disposing);
        }
    }
}
'@
    
    $exitScript2 | Out-File -FilePath "$kioskDir\EmergencyExitHotkey.cs" -Encoding UTF8
    
    # Exit Script 3: PowerShell emergency exit
    $exitScript3 = @'
# Emergency Exit from Kiosk Mode
Write-Host "========================================" -ForegroundColor Red
Write-Host "     EMERGENCY KIOSK MODE EXIT" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "WARNING: This will disable kiosk mode and restore normal Windows."
Write-Host ""

$confirm = Read-Host "Are you sure you want to exit kiosk mode? (YES/NO)"
if ($confirm -ne "YES") {
    Write-Host "Exit cancelled." -ForegroundColor Green
    pause
    exit
}

Write-Host "`nRestoring normal Windows configuration..." -ForegroundColor Yellow

# 1. Restore Explorer as shell
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $regPath -Name "Shell" -Value "explorer.exe" -Force
Write-Host "  ✓ Restored Windows Explorer as shell" -ForegroundColor Green

# 2. Remove auto-login
Remove-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $regPath -Name "DefaultUsername" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
Write-Host "  ✓ Disabled auto-login" -ForegroundColor Green

# 3. Remove scheduled tasks
Get-ScheduledTask -TaskName "Kiosk*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
Write-Host "  ✓ Removed kiosk scheduled tasks" -ForegroundColor Green

# 4. Remove registry restrictions
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Get-ItemProperty -Path $path | 
            Get-Member -MemberType NoteProperty | 
            Where-Object {$_.Name -like "*Disable*" -or $_.Name -like "*No*"} |
            ForEach-Object {
                Remove-ItemProperty -Path $path -Name $_.Name -ErrorAction SilentlyContinue
            }
    }
}
Write-Host "  ✓ Removed all restrictions" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "KIOSK MODE SUCCESSFULLY DISABLED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nPlease restart your computer for changes to take effect." -ForegroundColor Yellow

$restart = Read-Host "`nRestart now? (Y/N)"
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Restart-Computer -Force
}
'@
    
    $exitScript3 | Out-File -FilePath "$kioskDir\EmergencyExit.ps1" -Encoding UTF8
    
    # ============================================
    # 5. Create Application Monitor (NOT Restrictive)
    # ============================================
    Write-Log "Creating application monitor (non-restrictive)..."
    
    $monitorScript = @'
# Application Monitor - Logs activity but doesn't block
# This is SAFE - it only monitors, doesn't restrict

$logFile = "C:\ProgramData\SafeKiosk\Activity.log"
$lastLogTime = Get-Date

# Log startup
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Kiosk Monitor Started" | Out-File $logFile -Append

while ($true) {
    try {
        $currentTime = Get-Date
        
        # Log every 5 minutes
        if (($currentTime - $lastLogTime).TotalMinutes -ge 5) {
            $lastLogTime = $currentTime
            
            # Get running applications (with windows)
            $apps = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object ProcessName, Id
            
            "[$(Get-Date -Format 'HH:mm:ss')] Active apps: $($apps.Count)" | Out-File $logFile -Append
            foreach ($app in $apps) {
                "[$(Get-Date -Format 'HH:mm:ss')]   - $($app.ProcessName) (PID: $($app.Id))" | Out-File $logFile -Append
            }
        }
        
        # Check for emergency exit file
        if (Test-Path "C:\ProgramData\SafeKiosk\EXIT_NOW.txt") {
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Emergency exit triggered by file" | Out-File $logFile -Append
            Remove-Item "C:\ProgramData\SafeKiosk\EXIT_NOW.txt" -Force
            Start-Process "C:\ProgramData\SafeKiosk\EmergencyExit.ps1"
            break
        }
        
        Start-Sleep -Seconds 10
    }
    catch {
        # Continue monitoring on error
    }
}
'@
    
    $monitorScript | Out-File -FilePath "$kioskDir\AppMonitor.ps1" -Encoding UTF8
    
    # ============================================
    # 6. Configure Startup (Safe - keeps Windows shell)
    # ============================================
    Write-Log "Configuring startup items (safe method)..."
    
    # Create startup script for kiosk user
    $startupDir = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    $startupScript = @'
@echo off
REM Safe Kiosk Startup - Runs WITH Windows Explorer

REM Wait for Windows to fully start
timeout /t 10 /nobreak >nul

REM Start application monitor (non-restrictive)
start /min powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\ProgramData\SafeKiosk\AppMonitor.ps1"

REM Start Chrome in kiosk mode
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk --fullscreen https://www.google.com

REM Create desktop notification
echo Kiosk Mode Active. Check 'Allowed Applications' folder on desktop. > "C:\ProgramData\SafeKiosk\status.txt"
'@
    
    $startupScript | Out-File -FilePath "$startupDir\KioskStartup.bat" -Encoding ASCII
    
    # ============================================
    # 7. Configure Auto-Login (Optional - Can Disable)
    # ============================================
    Write-Host "`nAuto-Login Configuration:" -ForegroundColor Yellow
    Write-Host "Auto-login is convenient but makes it harder to exit." -ForegroundColor White
    Write-Host "For maximum safety, you can skip auto-login." -ForegroundColor White
    $enableAutoLogin = Read-Host "Enable auto-login? (Y/N - Recommended: N for safety)"
    
    if ($enableAutoLogin -eq 'Y' -or $enableAutoLogin -eq 'y') {
        Write-Log "Configuring auto-login..."
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
        Set-ItemProperty -Path $registryPath -Name "DefaultUsername" -Value $KioskUser -Type String -Force
        Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value $KioskPassword -Type String -Force
        Write-Log "Auto-login enabled (password will be visible in registry)"
    } else {
        Write-Log "Auto-login skipped for safety"
    }
    
    # ============================================
    # 8. Create Scheduled Tasks for Monitoring
    # ============================================
    Write-Log "Creating monitoring tasks..."
    
    # Task 1: Application monitor
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$kioskDir\AppMonitor.ps1`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName "KioskAppMonitor" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    
    # ============================================
    # 9. Create Desktop Environment
    # ============================================
    Write-Log "Creating desktop environment..."
    
    # Create user's desktop directory
    $userDesktop = "C:\Users\$KioskUser\Desktop"
    if (-not (Test-Path $userDesktop)) {
        New-Item -ItemType Directory -Path $userDesktop -Force | Out-Null
    }
    
    # Copy the launcher to desktop
    Copy-Item -Path "$kioskDir\Launcher.ps1" -Destination "$userDesktop\Kiosk Launcher.ps1" -Force
    
    # ============================================
    # 10. Create README File with Exit Instructions
    # ============================================
    Write-Log "Creating documentation..."
    
    $readmeContent = @"
========================================
         SAFE KIOSK MODE
========================================

This kiosk mode is designed to be SAFE and EASY TO EXIT.

ALLOWED APPLICATIONS:
----------------------
1. Google Chrome (starts automatically in kiosk mode)
2. Microsoft Edge
3. Visual Studio Code
4. File Explorer
5. PowerShell
6. Command Prompt
7. Notepad
8. Task Manager

All applications are accessible from:
• 'Allowed Applications' folder on Desktop
• Windows Start Menu (press Windows key)
• Taskbar (icons can be pinned)

HOW TO USE:
-----------
- Chrome starts automatically in fullscreen kiosk mode
- To exit Chrome fullscreen: Press Alt+F4 or F11
- To access other apps: Press Windows key or check Desktop
- All Windows functionality is preserved

EMERGENCY EXIT METHODS (5 Ways):
-------------------------------
1. DESKTOP SHORTCUT: Click 'Exit Kiosk Mode.lnk' on Desktop
2. HOTKEY: Press Ctrl+Shift+E three times quickly
3. POWER SHELL: Run C:\ProgramData\SafeKiosk\EmergencyExit.ps1
4. BATCH FILE: Run C:\ProgramData\SafeKiosk\ExitKiosk.bat
5. MANUAL RESTORE: Restart in Safe Mode and run cleanup

TO EXIT CHROME KIOSK MODE:
--------------------------
- Alt+F4 to close Chrome
- F11 to toggle fullscreen
- Click the X button (if visible)
- Use Task Manager (Ctrl+Shift+Esc)

NO RESTRICTIONS APPLIED:
-----------------------
- Task Manager: ENABLED (Ctrl+Shift+Esc)
- Windows Key: ENABLED
- Alt+Tab: ENABLED
- File Explorer: ENABLED
- All Windows features: ENABLED

This is a "soft" kiosk mode that only:
1. Auto-starts Chrome in kiosk mode
2. Creates convenient shortcuts
3. Monitors activity (doesn't restrict)

For help or to disable: Check C:\ProgramData\SafeKiosk\
========================================
"@
    
    $readmeContent | Out-File -FilePath "$kioskDir\README.txt" -Encoding UTF8
    Copy-Item -Path "$kioskDir\README.txt" -Destination "$userDesktop\KIOSK_README.txt" -Force
    
    # ============================================
    # 11. Compile Hotkey Exit Application
    # ============================================
    Write-Log "Compiling hotkey exit application..."
    
    try {
        # Try to compile C# hotkey exit
        Add-Type -TypeDefinition (Get-Content "$kioskDir\EmergencyExitHotkey.cs" -Raw) `
            -OutputAssembly "$kioskDir\EmergencyExitHotkey.exe" `
            -OutputType ConsoleApplication `
            -ReferencedAssemblies "System.Windows.Forms"
        
        # Add to startup
        $shortcut = $wshShell.CreateShortcut("$startupDir\EmergencyHotkey.lnk")
        $shortcut.TargetPath = "$kioskDir\EmergencyExitHotkey.exe"
        $shortcut.WindowStyle = 7  # Minimized
        $shortcut.Save()
        
        Write-Log "Hotkey exit application compiled"
    }
    catch {
        Write-Log "Note: Hotkey application could not be compiled. Other exit methods available."
    }
    
    # ============================================
    # 12. Final Configuration
    # ============================================
    Write-Log "Applying final configurations..."
    
    # Enable Task Manager (for safety!)
    $policiesPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (-not (Test-Path $policiesPath)) {
        New-Item -Path $policiesPath -Force | Out-Null
    }
    Set-ItemProperty -Path $policiesPath -Name "DisableTaskMgr" -Value 0 -Type DWord -Force
    
    # Enable Windows key
    $explorerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (-not (Test-Path $explorerPath)) {
        New-Item -Path $explorerPath -Force | Out-Null
    }
    Set-ItemProperty -Path $explorerPath -Name "NoWinKeys" -Value 0 -Type DWord -Force
    
    # Configure power settings (optional - keep screen on)
    powercfg -change -monitor-timeout-ac 30
    powercfg -change -standby-timeout-ac 60
    
    Write-Host "`n" + "="*50 -ForegroundColor Green
    Write-Host "       SAFE KIOSK MODE CONFIGURED!" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Green
    Write-Host ""
    Write-Host "SUMMARY:" -ForegroundColor Yellow
    Write-Host "--------" -ForegroundColor Yellow
    Write-Host "✓ Created user: $KioskUser" -ForegroundColor Green
    if ($enableAutoLogin -eq 'Y' -or $enableAutoLogin -eq 'y') {
        Write-Host "✓ Auto-login: ENABLED (password in registry)" -ForegroundColor Green
    } else {
        Write-Host "✓ Auto-login: DISABLED (safer)" -ForegroundColor Green
    }
    Write-Host "✓ Windows Explorer: ENABLED (full shell)" -ForegroundColor Green
    Write-Host "✓ Task Manager: ENABLED" -ForegroundColor Green
    Write-Host "✓ Windows Key: ENABLED" -ForegroundColor Green
    Write-Host ""
    Write-Host "ALLOWED APPLICATIONS:" -ForegroundColor Yellow
    Write-Host "---------------------" -ForegroundColor Yellow
    Write-Host "• Google Chrome (auto-starts in kiosk mode)" -ForegroundColor Cyan
    Write-Host "• Microsoft Edge" -ForegroundColor Cyan
    Write-Host "• Visual Studio Code" -ForegroundColor Cyan
    Write-Host "• File Explorer" -ForegroundColor Cyan
    Write-Host "• PowerShell" -ForegroundColor Cyan
    Write-Host "• Command Prompt" -ForegroundColor Cyan
    Write-Host "• Notepad" -ForegroundColor Cyan
    Write-Host "• Task Manager" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "EMERGENCY EXIT METHODS:" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Yellow
    Write-Host "1. Desktop shortcut: 'Exit Kiosk Mode'" -ForegroundColor White
    Write-Host "2. Hotkey: Ctrl+Shift+E (press 3 times)" -ForegroundColor White
    Write-Host "3. PowerShell: C:\ProgramData\SafeKiosk\EmergencyExit.ps1" -ForegroundColor White
    Write-Host "4. Batch file: C:\ProgramData\SafeKiosk\ExitKiosk.bat" -ForegroundColor White
    Write-Host "5. Safe Mode restart + cleanup" -ForegroundColor White
    Write-Host ""
    Write-Host "TO EXIT CHROME KIOSK:" -ForegroundColor Yellow
    Write-Host "• Alt+F4 or F11 or Task Manager" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: To test kiosk mode:" -ForegroundColor Red
    Write-Host "1. Switch user to '$KioskUser'" -ForegroundColor White
    Write-Host "2. Password: $KioskPassword" -ForegroundColor White
    Write-Host "3. Chrome will auto-start in kiosk mode" -ForegroundColor White
    Write-Host "4. Use Windows key to access other apps" -ForegroundColor White
    Write-Host ""
    Write-Host "All files are in: C:\ProgramData\SafeKiosk\" -ForegroundColor Cyan
    Write-Host "="*50 -ForegroundColor Green
    
    # Create test instructions
    $testInstructions = @"
To test the kiosk mode:

1. LOGOUT from current session (Start > User icon > Sign out)
2. LOGIN as user: $KioskUser
   Password: $KioskPassword
3. Chrome will auto-start in fullscreen kiosk mode
4. Press Windows key to access Start Menu
5. Check Desktop for 'Allowed Applications' folder
6. Try emergency exit methods to ensure they work

DO NOT restart until you've tested exit methods!
"@
    
    Write-Host "`n$testInstructions" -ForegroundColor Yellow
    
    $testNow = Read-Host "`nSwitch to kiosk user now to test? (Y/N - Recommended: Y)"
    if ($testNow -eq 'Y' -or $testNow -eq 'y') {
        Write-Host "Switching to kiosk user..." -ForegroundColor Cyan
        Start-Process "tsdiscon.exe"
    } else {
        Write-Host "`nTo test later:" -ForegroundColor Yellow
        Write-Host "1. Sign out from Start Menu" -ForegroundColor White
        Write-Host "2. Login as: $KioskUser" -ForegroundColor White
        Write-Host "3. Password: $KioskPassword" -ForegroundColor White
    }
    
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkYellow
    exit 1
}