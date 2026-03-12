param(
    [Parameter(Mandatory=$true)]
    [string]$AppName
)
 
Write-Host ""
Write-Host "-----------------------------------"
Write-Host " Application Installer"
Write-Host " Searching for: $AppName"
Write-Host "-----------------------------------"
Write-Host ""
 
# ============================================================
# Enable Winget via Policy
# ============================================================
 
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller"
 
if (!(Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}
 
Set-ItemProperty -Path $policyPath -Name EnableAppInstaller -Value 1 -Type DWord -Force
 
 
# ============================================================
# Try Winget Install
# ============================================================
 
$winget = Get-Command winget -ErrorAction SilentlyContinue
 
if ($winget) {
 
    Write-Host "Trying to install via Winget..."
 
    try {
 
        winget install $AppName `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --force
 
        if ($LASTEXITCODE -eq 0) {
 
            Write-Host ""
            Write-Host "SUCCESS: Installed via Winget"
            exit
        }
        else {
            Write-Host "Winget could not install $AppName"
        }
 
    }
    catch {
        Write-Host "Winget install failed"
    }
 
}
else {
    Write-Host "Winget not found on system"
}
 
# ============================================================
# Install Chocolatey (if missing)
# ============================================================
 
$choco = Get-Command choco -ErrorAction SilentlyContinue
 
if (!$choco) {
 
    Write-Host ""
    Write-Host "Chocolatey not found. Installing Chocolatey..."
 
    Set-ExecutionPolicy Bypass -Scope Process -Force
 
    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
 
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
 
    Start-Sleep -Seconds 5
}
 
# Refresh path
$env:Path += ";C:\ProgramData\chocolatey\bin"
 
# ============================================================
# Try Chocolatey Install
# ============================================================
 
Write-Host ""
Write-Host "Trying to install via Chocolatey..."
 
try {
 
    choco install $AppName -y
 
    if ($LASTEXITCODE -eq 0) {
 
        Write-Host ""
        Write-Host "SUCCESS: Installed via Chocolatey"
        exit
    }
    else {
 
        Write-Host ""
        Write-Host "Chocolatey could not install $AppName"
    }
 
}
catch {
 
    Write-Host "Chocolatey install failed"
 
}
 
# ============================================================
# If nothing worked
# ============================================================
 
Write-Host ""
Write-Host "ERROR: Application not found in Winget or Chocolatey."
Write-Host ""