param(
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

# ============================================================
# LOGGING
# ============================================================

$LogDir = "C:\Logs"
$LogFile = "$LogDir\AppInstall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if (!(Test-Path $LogDir)) {
    New-Item $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$msg)

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$time : $msg"

    Write-Host $msg
    Add-Content $LogFile $line
}

Write-Log ""
Write-Log "-----------------------------------"
Write-Log "Application Installer Started"
Write-Log "Searching for: $AppName"
Write-Log "-----------------------------------"

# ============================================================
# ENABLE WINGET POLICY
# ============================================================

$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppInstaller"

if (!(Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}

Set-ItemProperty -Path $policyPath -Name EnableAppInstaller -Value 1 -Type DWord -Force

# ============================================================
# CHECK WINGET
# ============================================================

$winget = Get-Command winget -ErrorAction SilentlyContinue

if ($winget) {

    Write-Log "Winget detected"
    Write-Log "Running: winget show $AppName"

    $output = winget show $AppName 2>&1

    $productId = $null

    foreach ($line in $output) {

        if ($line -match "\[(.*?)\]") {

            $productId = $Matches[1]
            break
        }
    }

    if ($productId) {

        Write-Log "Product ID found: $productId"
        Write-Log "Installing via Winget..."

        winget install --id $productId `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --force

        if ($LASTEXITCODE -eq 0) {

            Write-Log "SUCCESS: Installed via Winget"
            exit
        }
        else {

            Write-Log "Winget installation failed"
        }
    }
    else {

        Write-Log "Winget product ID not found"
    }

}
else {

    Write-Log "Winget not found"
}

# ============================================================
# CHOCOLATEY INSTALL
# ============================================================

$choco = Get-Command choco -ErrorAction SilentlyContinue

if (!$choco) {

    Write-Log "Chocolatey not found. Installing..."
    Write-Log "Chocolatey not found. Installing..."

    Set-ExecutionPolicy Bypass -Scope Process -Force

    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    Start-Sleep 5
}

$env:Path += ";C:\ProgramData\chocolatey\bin"

Write-Log "Searching Chocolatey..."

$chocoSearch = choco search $AppName

foreach ($line in $chocoSearch) {

    if ($line -match "^$AppName") {

        $pkg = $line.Split(" ")[0]

        Write-Log "Chocolatey package found: $pkg"
        Write-Log "Installing via Chocolatey..."

        choco install $pkg -y --no-progress

        if ($LASTEXITCODE -eq 0) {

            Write-Log "SUCCESS: Installed via Chocolatey"
            exit
        }
        else {

            Write-Log "Chocolatey installation failed"
            break
        }
    }
}

Write-Log "ERROR: Application not found in Winget or Chocolatey"
exit 1
