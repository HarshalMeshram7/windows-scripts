# Run as Administrator

Write-Host "Checking Winget installation..." -ForegroundColor Cyan

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Winget is already installed." -ForegroundColor Green
} else {
    Write-Host "Winget not found. Installing App Installer from Microsoft Store..." -ForegroundColor Yellow
    Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
    Write-Host "Follow the installer prompt to complete Winget installation."
}

Write-Host "`nChecking Chocolatey installation..." -ForegroundColor Cyan

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = 3072

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    Write-Host "Chocolatey installation completed." -ForegroundColor Green
}

Write-Host "`nVerifying installations..." -ForegroundColor Cyan

winget --version
choco -v

Write-Host "`nSetup Complete!" -ForegroundColor Green