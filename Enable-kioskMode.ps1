# ============================================
# Chrome + PowerShell Kiosk Mode
# ============================================

#Requires -RunAsAdministrator

param(
    [string]$KioskUser = "KioskUser",
    [string]$KioskPassword = "P@ssw0rd123",
    [string]$ChromeWebsite = "https://www.google.com"
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Cyan
    Add-Content -Path "C:\KioskSetup.log" -Value "[$timestamp] $Message"
}

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Log "Starting Chrome + PowerShell Kiosk Mode Configuration..."

try {
    # ============================================
    # 1. Create Kiosk User Account
    # ============================================
    Write-Log "Creating kiosk user account..."
    
    $userExists = Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue
    
    if (-not $userExists) {
        $securePassword = ConvertTo-SecureString $KioskPassword -AsPlainText -Force
        New-LocalUser -Name $KioskUser -Password $securePassword `
            -FullName "Kiosk User" `
            -Description "Chrome + PowerShell Kiosk" `
            -AccountNeverExpires
        Write-Log "Created kiosk user: $KioskUser"
    } else {
        Write-Log "Kiosk user already exists"
    }
    
    # ============================================
    # 2. Create Custom Shell Script
    # ============================================
    Write-Log "Creating custom shell..."
    
    $kioskDir = "C:\ProgramData\ChromePowerShellKiosk"
    if (-not (Test-Path $kioskDir)) {
        New-Item -ItemType Directory -Path $kioskDir -Force | Out-Null
    }
    
    # Create PowerShell script that will act as our shell
    $shellScript = @'
# Chrome + PowerShell Kiosk Shell
# This script replaces Windows Explorer as the shell

# Hide PowerShell window
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Window {
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
}
"@

$consolePtr = [Window]::GetConsoleWindow()
[Window]::ShowWindow($consolePtr, 0) | Out-Null

# Paths
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$website = "https://www.google.com"

# Launch Chrome in kiosk mode
try {
    Start-Process -FilePath $chromePath -ArgumentList "--kiosk --fullscreen $website" -WindowStyle Maximized
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Chrome launched" | Out-File "C:\ProgramData\ChromePowerShellKiosk\shell.log" -Append
} catch {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Chrome launch failed: $_" | Out-File "C:\ProgramData\ChromePowerShellKiosk\shell.log" -Append
}

# Create PowerShell shortcut on desktop
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktopPath\PowerShell.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.WorkingDirectory = "C:\"
$shortcut.Save()

# Create simple task switcher
Write-Host "========================================"
Write-Host "    Chrome + PowerShell Kiosk Mode"
Write-Host "========================================"
Write-Host ""
Write-Host "Available Applications:"
Write-Host "1. Google Chrome (Fullscreen Kiosk Mode)"
Write-Host "2. PowerShell (via Desktop shortcut)"
Write-Host ""
Write-Host "Press Alt+F4 to close applications"
Write-Host "========================================"

# Keep shell running
while ($true) {
    # Monitor Chrome and restart if closed
    $chromeProcess = Get-Process "chrome" -ErrorAction SilentlyContinue
    if (-not $chromeProcess) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Chrome not running, restarting..." | Out-File "C:\ProgramData\ChromePowerShellKiosk\shell.log" -Append
        Start-Process -FilePath $chromePath -ArgumentList "--kiosk --fullscreen $website" -WindowStyle Maximized
    }
    
    Start-Sleep -Seconds 10
}
'@
    
    $shellScript | Out-File -FilePath "$kioskDir\Shell.ps1" -Encoding UTF8
    
    # ============================================
    # 3. Create Process Filter (Allow only Chrome & PowerShell)
    # ============================================
    Write-Log "Creating process filter..."
    
    $filterScript = @'
# Process Filter - Only allow Chrome and PowerShell
# Run this with highest privileges

# Allowed processes (case-insensitive)
$allowedProcesses = @("chrome", "powershell", "pwsh", "powershell_ise", "conhost")

# Special allowed Windows processes (required for system)
$allowedWindowsProcesses = @("csrss", "wininit", "services", "lsass", "svchost", "dwm", "fontdrvhost")

while ($true) {
    try {
        # Get all processes
        $allProcesses = Get-Process -ErrorAction SilentlyContinue
        
        foreach ($process in $allProcesses) {
            $processName = $process.ProcessName.ToLower()
            
            # Skip if process is in allowed lists
            if ($processName -in $allowedProcesses -or $processName -in $allowedWindowsProcesses) {
                continue
            }
            
            # Skip system processes and services
            if ($process.SessionId -eq 0) {  # Session 0 = system processes
                continue
            }
            
            # Skip Explorer if it's our shell replacement
            if ($processName -eq "explorer") {
                continue
            }
            
            # Check if process has a visible window (we want to block these)
            if ($process.MainWindowHandle -ne 0) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Blocking windowed process: $($process.ProcessName) (PID: $($process.Id))" | Out-File "C:\ProgramData\ChromePowerShellKiosk\filter.log" -Append
                
                try {
                    # Try to close gracefully first
                    $process.CloseMainWindow() | Out-Null
                    Start-Sleep -Milliseconds 500
                    
                    # Force kill if still running
                    if (-not $process.HasExited) {
                        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    # Silent fail
                }
            }
        }
        
        # Check for Task Manager specifically
        $taskmgr = Get-Process "Taskmgr" -ErrorAction SilentlyContinue
        if ($taskmgr) {
            Stop-Process -Name "Taskmgr" -Force -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Task Manager blocked" | Out-File "C:\ProgramData\ChromePowerShellKiosk\filter.log" -Append
        }
        
        # Check for Command Prompt
        $cmd = Get-Process "cmd" -ErrorAction SilentlyContinue
        if ($cmd) {
            Stop-Process -Name "cmd" -Force -ErrorAction SilentlyContinue
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Command Prompt blocked" | Out-File "C:\ProgramData\ChromePowerShellKiosk\filter.log" -Append
        }
        
        Start-Sleep -Seconds 1
    }
    catch {
        # Continue on error
    }
}
'@
    
    $filterScript | Out-File -FilePath "$kioskDir\ProcessFilter.ps1" -Encoding UTF8
    
    # ============================================
    # 4. Replace Windows Shell
    # ============================================
    Write-Log "Replacing Windows Shell..."
    
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    
    # Backup current shell
    $currentShell = (Get-ItemProperty -Path $registryPath -Name "Shell" -ErrorAction SilentlyContinue).Shell
    if ($currentShell) {
        Set-ItemProperty -Path $registryPath -Name "Shell_Backup" -Value $currentShell -Force
        Write-Log "Backed up current shell: $currentShell"
    }
    
    # Set our PowerShell script as the new shell
    $newShell = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$kioskDir\Shell.ps1`""
    Set-ItemProperty -Path $registryPath -Name "Shell" -Value $newShell -Force
    Write-Log "Set new shell: $newShell"
    
    # ============================================
    # 5. Configure Auto-Login
    # ============================================
    Write-Log "Configuring auto-login..."
    
    Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1" -Type String -Force
    Set-ItemProperty -Path $registryPath -Name "DefaultUsername" -Value $KioskUser -Type String -Force
    Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value $KioskPassword -Type String -Force
    Set-ItemProperty -Path $registryPath -Name "ForceAutoLogon" -Value "1" -Type String -Force
    
    # ============================================
    # 6. Create Startup Task for Process Filter
    # ============================================
    Write-Log "Creating process filter task..."
    
    # Create scheduled task for process filter
    $taskName = "KioskProcessFilter"
    $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($taskExists) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$kioskDir\ProcessFilter.ps1`""
    
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "Process filter task created"
    
    # ============================================
    # 7. Disable System Features
    # ============================================
    Write-Log "Configuring system restrictions..."
    
    # Disable Task Manager via registry
    $policiesPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (-not (Test-Path $policiesPath)) {
        New-Item -Path $policiesPath -Force | Out-Null
    }
    Set-ItemProperty -Path $policiesPath -Name "DisableTaskMgr" -Value 1 -Type DWord -Force
    
    # Hide other users from login screen
    Set-ItemProperty -Path $policiesPath -Name "DontDisplayLastUserName" -Value 1 -Type DWord -Force
    
    # Disable lock screen
    $personalizationPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    if (-not (Test-Path $personalizationPath)) {
        New-Item -Path $personalizationPath -Force | Out-Null
    }
    Set-ItemProperty -Path $personalizationPath -Name "NoLockScreen" -Value 1 -Type DWord -Force
    
    # Disable Windows key
    $explorerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    if (-not (Test-Path $explorerPath)) {
        New-Item -Path $explorerPath -Force | Out-Null
    }
    Set-ItemProperty -Path $explorerPath -Name "NoWinKeys" -Value 1 -Type DWord -Force
    
    # ============================================
    # 8. Configure Power Settings
    # ============================================
    Write-Log "Configuring power settings..."
    
    # Disable sleep and screen timeout
    powercfg -change -standby-timeout-ac 0
    powercfg -change -standby-timeout-dc 0
    powercfg -change -monitor-timeout-ac 0
    powercfg -change -monitor-timeout-dc 0
    
    # ============================================
    # 9. Create Chrome Kiosk Profile
    # ============================================
    Write-Log "Creating Chrome kiosk profile..."
    
    $chromeProfileDir = "C:\ProgramData\ChromeKioskProfile"
    if (-not (Test-Path $chromeProfileDir)) {
        New-Item -ItemType Directory -Path $chromeProfileDir -Force | Out-Null
    }
    
    # Create Chrome shortcut with profile
    $chromeShortcut = @"
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
    --kiosk ^
    --fullscreen ^
    --no-first-run ^
    --disable-infobars ^
    --disable-session-crashed-bubble ^
    --disable-features=InfiniteSessionRestore ^
    --no-default-browser-check ^
    --user-data-dir="$chromeProfileDir" ^
    $ChromeWebsite
"@
    
    $chromeShortcut | Out-File -FilePath "$kioskDir\StartChrome.bat" -Encoding ASCII
    
    # ============================================
    # 10. Create Desktop Environment for Kiosk User
    # ============================================
    Write-Log "Creating desktop environment..."
    
    # Create user's desktop directory if it doesn't exist
    $userDesktop = "C:\Users\$KioskUser\Desktop"
    if (-not (Test-Path $userDesktop)) {
        New-Item -ItemType Directory -Path $userDesktop -Force | Out-Null
    }
    
    # Create PowerShell shortcut on desktop
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut("$userDesktop\PowerShell.lnk")
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.WorkingDirectory = "C:\"
    $shortcut.Save()
    
    # Create Chrome shortcut on desktop (for switching back from PowerShell)
    $shortcut = $wshShell.CreateShortcut("$userDesktop\Chrome.lnk")
    $shortcut.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    $shortcut.Arguments = "--kiosk --fullscreen $ChromeWebsite"
    $shortcut.WorkingDirectory = "C:\Program Files\Google\Chrome\Application"
    $shortcut.Save()
    
    # ============================================
    # 11. Configure User Permissions
    # ============================================
    Write-Log "Configuring user permissions..."
    
    # Grant full control to kiosk directory for kiosk user
    $acl = Get-Acl $kioskDir
    $userSid = (Get-LocalUser -Name $KioskUser).SID
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($userSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl -Path $kioskDir -AclObject $acl
    
    Write-Log "============================================"
    Write-Log "CHROME + POWERSHELL KIOSK MODE CONFIGURED!" -ForegroundColor Green
    Write-Log "============================================"
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Yellow
    Write-Host "1. Kiosk User: $KioskUser" -ForegroundColor White
    Write-Host "2. Password: $KioskPassword" -ForegroundColor White
    Write-Host "3. Auto-login: Enabled" -ForegroundColor White
    Write-Host "4. Allowed Applications:" -ForegroundColor White
    Write-Host "   - Google Chrome (Kiosk Mode)" -ForegroundColor Cyan
    Write-Host "   - PowerShell" -ForegroundColor Cyan
    Write-Host "5. Website: $ChromeWebsite" -ForegroundColor White
    Write-Host "6. Restrictions:" -ForegroundColor White
    Write-Host "   - No Task Manager" -ForegroundColor White
    Write-Host "   - No Windows key" -ForegroundColor White
    Write-Host "   - No lock screen" -ForegroundColor White
    Write-Host "   - No sleep/power saving" -ForegroundColor White
    Write-Host ""
    Write-Host "How to use:" -ForegroundColor Yellow
    Write-Host "- System auto-logs in to kiosk mode" -ForegroundColor White
    Write-Host "- Chrome starts in fullscreen kiosk mode" -ForegroundColor White
    Write-Host "- Switch to PowerShell via Alt+Tab or desktop shortcut" -ForegroundColor White
    Write-Host "- Switch back to Chrome via desktop shortcut or Alt+Tab" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: To exit kiosk mode:" -ForegroundColor Red
    Write-Host "1. Restart in Safe Mode (Shift + Restart)" -ForegroundColor White
    Write-Host "2. Run the cleanup script as Administrator" -ForegroundColor White
    Write-Host "============================================"
    
    # Save cleanup instructions
    $cleanupInstructions = @"
# To restore normal Windows:
# 1. Restart in Safe Mode (Shift + Restart > Troubleshoot > Advanced > Startup Settings > Restart > F4)
# 2. Run PowerShell as Administrator
# 3. Execute these commands:

# Restore original shell
`$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
`$backupShell = (Get-ItemProperty -Path `$regPath -Name "Shell_Backup" -ErrorAction SilentlyContinue).Shell_Backup
if (`$backupShell) {
    Set-ItemProperty -Path `$regPath -Name "Shell" -Value `$backupShell -Force
    Remove-ItemProperty -Path `$regPath -Name "Shell_Backup" -ErrorAction SilentlyContinue
} else {
    Set-ItemProperty -Path `$regPath -Name "Shell" -Value "explorer.exe" -Force
}

# Remove auto-login
Remove-ItemProperty -Path `$regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path `$regPath -Name "DefaultUsername" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path `$regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path `$regPath -Name "ForceAutoLogon" -ErrorAction SilentlyContinue

# Remove scheduled task
Unregister-ScheduledTask -TaskName "KioskProcessFilter" -Confirm:`$false -ErrorAction SilentlyContinue

# Remove restrictions
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DontDisplayLastUserName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys" -ErrorAction SilentlyContinue

# Restart computer
Restart-Computer -Force
"@
    
    $cleanupInstructions | Out-File -FilePath "$kioskDir\RestoreInstructions.ps1" -Encoding UTF8
    
    # Prompt for restart
    $restart = Read-Host "`nConfiguration complete. Restart now to start kiosk mode? (Y/N)"
    if ($restart -eq 'Y' -or $restart -eq 'y') {
        Write-Log "Restarting computer..."
        Restart-Computer -Force
    }
    
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor DarkYellow
    exit 1
}