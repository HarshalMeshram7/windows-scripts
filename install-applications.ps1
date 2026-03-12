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
# STEP 1: Check if already installed (Winget)
# ------------------------------------------------

$winget = Get-Command winget -ErrorAction SilentlyContinue

if ($winget) {
    $installedOutput = winget list 2>&1 | Where-Object {
        $_ -match $AppName
    }

    if ($installedOutput) {
        Write-Host ""
        Write-Host "'$AppName' is already installed. Skipping installation."
        exit
    }
}

# ------------------------------------------------
# STEP 2: Search and install via Winget
# ------------------------------------------------

if ($winget) {

    Write-Host ""
    Write-Host "Searching Winget repository..."

    $results = winget search $AppName 2>&1 | Where-Object {
        $_ -match '\w' -and
        $_ -notmatch "Name\s+Id\s+Version" -and
        $_ -notmatch "^-+$" -and
        $_ -notmatch "No package found"
    }

    $first = $results | Select-Object -First 1

    if ($first) {

        $cols = $first -split '\s{2,}'

        if ($cols.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($cols[1])) {

            $pkgName = $cols[0].Trim()
            $pkgId   = $cols[1].Trim()

            Write-Host "Found in Winget:"
            Write-Host "Name: $pkgName"
            Write-Host "ID:   $pkgId"

            winget install --id $pkgId `
                --exact `
                --silent `
                --accept-package-agreements `
                --accept-source-agreements `
                --force

            Write-Host "Installed '$pkgName' via Winget."
            exit
        }
    }

    Write-Host "Not found in Winget. Trying Chocolatey..."
}

# ------------------------------------------------
# STEP 3: Fallback - Search and install via Chocolatey
# ------------------------------------------------

$choco = Get-Command choco -ErrorAction SilentlyContinue

if (!$choco) {

    Write-Host ""
    Write-Host "Installing Chocolatey..."

    Set-ExecutionPolicy Bypass -Scope Process -Force

    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    $choco = Get-Command choco -ErrorAction SilentlyContinue
}

if ($choco) {

    Write-Host ""
    Write-Host "Searching Chocolatey..."

    # Check if already installed via Chocolatey
    $chocoInstalled = choco list --limit-output 2>&1 | Where-Object {
        $_ -match "^$([regex]::Escape($AppName))\|"
    }

    if ($chocoInstalled) {
        Write-Host ""
        Write-Host "'$AppName' is already installed via Chocolatey. Skipping installation."
        exit
    }

    $pkg = choco search $AppName --limit-output 2>&1 | Select-Object -First 1

    if ($pkg) {

        $pkgName = $pkg.Split('|')[0]

        Write-Host "Found in Chocolatey: $pkgName"

        choco install $pkgName -y

        Write-Host "Installed '$pkgName' via Chocolatey."
    }
    else {
        Write-Host ""
        Write-Host "'$AppName' was not found in Winget or Chocolatey. Please install it manually."
    }
}
