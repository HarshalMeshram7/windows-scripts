# Safe4Sure - Hide Uninstall Options Only
# Run as Administrator

$LogFile = "C:\ProgramData\safe4sure_protection.log"

function Write-Log {
    param([string]$msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $LogFile "$time - $msg"
}

Write-Log "Applying uninstall protection"

# -------------------------------------------------
# Hide Programs and Features
# -------------------------------------------------

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs" -Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs" `
-Name "NoProgramsAndFeatures" `
-Value 1 `
-PropertyType DWORD `
-Force | Out-Null

Write-Log "Control Panel uninstall hidden"

# -------------------------------------------------
# Hide Apps & Features
# -------------------------------------------------

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
-Name "SettingsPageVisibility" `
-Value "hide:appsfeatures" `
-PropertyType String `
-Force | Out-Null

Write-Log "Settings uninstall page hidden"

# -------------------------------------------------
# Disable Add/Remove programs page
# -------------------------------------------------

New-ItemProperty `
-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs" `
-Name "NoAddRemovePrograms" `
-Value 1 `
-PropertyType DWORD `
-Force | Out-Null

Write-Log "Add/Remove programs disabled"
