# Safe4Sure Revert Script
# Run as Administrator

$LogFile = "C:\ProgramData\safe4sure_protection.log"

function Write-Log {
    param([string]$msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $LogFile "$time - $msg"
}

Write-Log "Starting Safe4Sure protection revert..."

# -------------------------------------------------
# Restore Programs and Features (Control Panel)
# -------------------------------------------------

$programsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs"

if (Test-Path $programsPath) {

    Remove-ItemProperty `
    -Path $programsPath `
    -Name "NoProgramsAndFeatures" `
    -ErrorAction SilentlyContinue

    Remove-ItemProperty `
    -Path $programsPath `
    -Name "NoAddRemovePrograms" `
    -ErrorAction SilentlyContinue

    Write-Log "Programs and Features restored"
}

# -------------------------------------------------
# Restore Apps & Features page
# -------------------------------------------------

$explorerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"

if (Test-Path $explorerPath) {

    Remove-ItemProperty `
    -Path $explorerPath `
    -Name "SettingsPageVisibility" `
    -ErrorAction SilentlyContinue

    Write-Log "Settings Apps & Features restored"
}

# -------------------------------------------------
# Remove Safe4Sure service protection
# -------------------------------------------------

$serviceName = "safe4sure"

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {

    sc.exe sdset $serviceName "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRRC;;;BA)"

    Write-Log "Safe4Sure service permissions restored"
}

# -------------------------------------------------
# Refresh policies
# -------------------------------------------------

gpupdate /force | Out-Null

Write-Log "System policies refreshed"
Write-Log "Safe4Sure protection successfully reverted"
Write-Log "-------------------------------------------"