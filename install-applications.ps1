param(
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

Write-Host "-----------------------------------"
Write-Host "Application Installer"
Write-Host "Searching for: $AppName"
Write-Host "-----------------------------------"

# Enable Winget policy
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller"

if (!(Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}

Set-ItemProperty -Path $policyPath -Name EnableAppInstaller -Value 1 -Type DWord

# ------------------------------------------------
# Try Winget
# ------------------------------------------------

$winget = Get-Command winget -ErrorAction SilentlyContinue

if ($winget) {

    Write-Host ""
    Write-Host "Searching Winget repository..."

    $results = winget search $AppName | Where-Object {
        $_ -match '\w' -and
        $_ -notmatch "Name\s+Id\s+Version" -and
        $_ -notmatch "^-+$"
    }

    $first = $results | Select-Object -First 1

    if ($first) {

        $cols = $first -split '\s{2,}'

        $pkgName = $cols[0]
        $pkgId = $cols[1]

        Write-Host "Found in Winget:"
        Write-Host "Name: $pkgName"
        Write-Host "ID: $pkgId"

        winget install --id $pkgId `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --force

        Write-Host "Installed via Winget"
        exit
    }

    Write-Host "Not found in Winget"
}

# ------------------------------------------------
# Chocolatey fallback
# ------------------------------------------------

$choco = Get-Command choco -ErrorAction SilentlyContinue

if (!$choco) {

    Write-Host ""
    Write-Host "Installing Chocolatey..."

    Set-ExecutionPolicy Bypass -Scope Process -Force

    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

Write-Host ""
Write-Host "Searching Chocolatey..."

$pkg = choco search $AppName --limit-output | Select-Object -First 1

if ($pkg) {

    $pkgName = $pkg.Split('|')[0]

    Write-Host "Found in Chocolatey: $pkgName"

    choco install $pkgName -y

    Write-Host "Installed via Chocolatey"
}
else {

    Write-Host ""
    Write-Host "Application not found in Winget or Chocolatey."
}