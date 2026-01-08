# Kiosk-Mode-Disable.ps1
# PowerShell script to disable Kiosk mode and remove Kiosk user

# Configuration
$KioskUserName = "KioskUser"
$LogFile = "C:\Windows\Logs\Kiosk-Removal.log"

# Function for logging
function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$TimeStamp - $Message"
    Write-Output $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

# Start logging
Start-Transcript -Path $LogFile -Append -ErrorAction SilentlyContinue
Write-Log "Starting Kiosk Mode removal..."

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "ERROR: This script requires Administrator privileges!"
    Stop-Transcript
    exit 1
}

# Disable Assigned Access (Kiosk Mode)
Write-Log "Disabling Assigned Access..."
try {
    $Namespace = "root\cimv2\mdm\dmmap"
    $ClassName = "MDM_AssignedAccess"
    
    $AssignedAccess = Get-WmiObject -Namespace $Namespace -Class $ClassName -ErrorAction SilentlyContinue
    if ($AssignedAccess) {
        $AssignedAccess.SetXml("")
        Write-Log "Assigned Access disabled."
    }
    
    # Alternative method - clear via MDM
    $AssignedAccessPath = "./Vendor/MSFT/AssignedAccess"
    try {
        Remove-Item "C:\Windows\System32\kioskconfig.xml" -ErrorAction SilentlyContinue
    } catch {}
} catch {
    Write-Log "WARNING: Could not disable Assigned Access: $_"
}

# Remove Kiosk user account
Write-Log "Removing Kiosk user account..."
try {
    $KioskUser = Get-LocalUser -Name $KioskUserName -ErrorAction SilentlyContinue
    if ($KioskUser) {
        # Kill all processes running under Kiosk user
        try {
            Get-Process -IncludeUserName -ErrorAction SilentlyContinue | 
                Where-Object { $_.UserName -like "*$KioskUserName*" } | 
                Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } catch {}
        
        # Remove user
        Remove-LocalUser -Name $KioskUserName -ErrorAction Stop
        Write-Log "Kiosk user account removed."
    } else {
        Write-Log "Kiosk user account not found."
    }
} catch {
    Write-Log "ERROR removing Kiosk user: $_"
}

# Restore registry settings from backup
Write-Log "Restoring registry settings..."
try {
    $BackupPath = "C:\Windows\KioskBackup"
    
    if (Test-Path $BackupPath) {
        # Import registry backups
        $RegFiles = Get-ChildItem -Path $BackupPath -Filter "*.reg" -ErrorAction SilentlyContinue
        foreach ($RegFile in $RegFiles) {
            try {
                reg import $RegFile.FullName 2>&1 | Out-Null
                Write-Log "Imported: $($RegFile.Name)"
            } catch {
                Write-Log "WARNING: Could not import $($RegFile.Name): $_"
            }
        }
    }
} catch {
    Write-Log "WARNING: Could not restore from backup: $_"
}

# Restore default registry settings
Write-Log "Restoring default system settings..."
try {
    # Enable Task Manager
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableTaskMgr" -ErrorAction SilentlyContinue
    
    # Enable Registry Editor
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableRegistryTools" -ErrorAction SilentlyContinue
    
    # Enable Command Prompt
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableCMD" -ErrorAction SilentlyContinue
    
    # Show shutdown options
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HidePowerOptions" -ErrorAction SilentlyContinue
    
    # Enable access to drives
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoViewOnDrive" -ErrorAction SilentlyContinue
    
    # Restore Start Menu
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoStartMenuMorePrograms" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoStartMenuSubFolders" -ErrorAction SilentlyContinue
    
    # Enable Lock and Switch Account
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableLockWorkstation" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "HideFastUserSwitching" -ErrorAction SilentlyContinue
    
    # Remove user profile registry entries
    $LocalUsers = Get-LocalUser -ErrorAction SilentlyContinue
    foreach ($User in $LocalUsers) {
        if ($User.Name -ne $KioskUserName) {
            $UserRegPath = "HKU\$($User.SID)\Software\Microsoft\Windows\CurrentVersion\Policies"
            try {
                Remove-Item -Path "$UserRegPath\System" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$UserRegPath\Explorer" -Recurse -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
} catch {
    Write-Log "WARNING: Some registry settings could not be restored: $_"
}

# Disable Auto-Logon
Write-Log "Disabling Auto-Logon..."
try {
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Remove-ItemProperty -Path $RegPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $RegPath -Name "DefaultUsername" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $RegPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $RegPath -Name "ForceAutoLogon" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $RegPath -Name "Shell" -Value "explorer.exe" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $RegPath -Name "DisableCAD" -ErrorAction SilentlyContinue
} catch {
    Write-Log "WARNING: Could not disable Auto-Logon: $_"
}

# Remove scheduled tasks
Write-Log "Removing scheduled tasks..."
try {
    Unregister-ScheduledTask -TaskName "KioskShellMonitor" -Confirm:$false -ErrorAction SilentlyContinue
} catch {
    Write-Log "WARNING: Could not remove scheduled task: $_"
}

# Clean up files
Write-Log "Cleaning up files..."
try {
    Remove-Item "C:\Windows\System32\kioskconfig.xml" -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\Logs\Kiosk-Setup.log" -ErrorAction SilentlyContinue
} catch {
    Write-Log "WARNING: Some files could not be removed: $_"
}

Write-Log "Kiosk Mode removal completed successfully!"
Stop-Transcript

Write-Host "Kiosk Mode has been disabled and Kiosk user removed." -ForegroundColor Green
Write-Host "A system restart is recommended to complete the restoration." -ForegroundColor Yellow
Write-Host "Log file: $LogFile" -ForegroundColor Gray

shutdown /r /t 0