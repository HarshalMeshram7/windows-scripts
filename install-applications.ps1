param(
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

# ============================================================
# LOGGING SETUP
# ============================================================

$LogDir  = "C:\Logs"
$Time    = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = "$LogDir\AppInstall_$AppName`_$Time.log"

if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp : $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

Write-Log "-----------------------------------"
Write-Log "Application Installer Started"
Write-Log "Searching for: $AppName"
Write-Log "-----------------------------------"

# ============================================================
# Enable Winget Policy
# ============================================================

$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller"

if (!(Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}

Set-ItemProperty -Path $policyPath -Name EnableAppInstaller -Value 1 -Type DWord -Force

Write-Log "Winget policy enabled"

# ============================================================
# Try Winget Install (System Wide)
# ============================================================

$winget = Get-Command winget -ErrorAction SilentlyContinue

if ($winget) {

    Write-Log "Trying installation via Winget..."

    try {

        winget install $AppName `
            --scope machine `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --force

        if ($LASTEXITCODE -eq 0) {

            Write-Log "SUCCESS: Installed via Winget"
            exit
        }
        else {
            Write-Log "Winget failed to install $AppName"
        }

    }
    catch {
        Write-Log "Winget install error: $_"
    }

}
else {
    Write-Log "Winget not found"
}

# ============================================================
# Install Chocolatey if Missing
# ============================================================

$choco = Get-Command choco -ErrorAction SilentlyContinue

if (!$choco) {

    Write-Log "Chocolatey not found. Installing..."

    Set-ExecutionPolicy Bypass -Scope Process -Force

    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    Start-Sleep -Seconds 5

    Write-Log "Chocolatey installed"
}

# Refresh PATH
$env:Path += ";C:\ProgramData\chocolatey\bin"

# ============================================================
# Try Chocolatey Install
# ============================================================

Write-Log "Trying installation via Chocolatey..."

try {

    choco install $AppName -y

    if ($LASTEXITCODE -eq 0) {

        Write-Log "SUCCESS: Installed via Chocolatey"
        exit
    }
    else {

        Write-Log "Chocolatey failed to install $AppName"
    }

}
catch {

    Write-Log "Chocolatey error: $_"

}

# ============================================================
# If nothing worked
# ============================================================

Write-Log "ERROR: Application not found in Winget or Chocolatey"
Write-Log "Installation Failed"
