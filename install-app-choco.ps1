param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$AppName
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Relaunching as Administrator..." -ForegroundColor Yellow
    $relaunchArgs = "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" `"$AppName`""
    Start-Process powershell -Verb RunAs -ArgumentList $relaunchArgs
    exit
}

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\AppInstall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if (!(Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host $Message
    Add-Content -Path $LogFile -Value "$ts : $Message"
}

Write-Log "================================================"
Write-Log "  App Installer (FORCE MODE - always reinstalls)"
Write-Log "  Target : $AppName"
Write-Log "  User   : $env:USERNAME"
Write-Log "  Date   : $(Get-Date)"
Write-Log "================================================"

$chocoPath = "C:\ProgramData\chocolatey\bin"
if ($env:Path -notlike "*$chocoPath*") {
    $env:Path += ";$chocoPath"
}

if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Start-Sleep -Seconds 5
    Write-Log "Chocolatey installed."
} else {
    Write-Log "Chocolatey found."
}

if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: Chocolatey still not available. Exiting."
    exit 1
}

choco feature enable --name=allowGlobalConfirmation --no-progress 2>&1 | Out-Null

Write-Log "Searching Chocolatey for '$AppName'..."
$searchOutput = choco search $AppName --limit-output 2>&1
$bestMatch = $null

foreach ($line in $searchOutput) {
    $parts = $line.Split('|')
    $pkg = $parts[0].Trim()
    if ($pkg -like "*$AppName*") {
        $bestMatch = $pkg
        break
    }
}

if (-not $bestMatch) {
    Write-Log "ERROR: No package found matching '$AppName'."
    Write-Log "================================================"
    exit 1
}

Write-Log "Best match: $bestMatch"
Write-Log "Installing '$bestMatch' for ALL users (forced, silent)..."
Write-Log "------------------------------------------------"

choco install $bestMatch --yes --no-progress --force --force-dependencies --ignore-checksums --override-arguments --install-arguments "ALLUSERS=1 /quiet /qn /norestart"

$exitCode = $LASTEXITCODE
Write-Log "------------------------------------------------"
Write-Log "Choco exit code: $exitCode"

if ($exitCode -eq 0) {
    Write-Log "Copying shortcuts to all user profiles..."

    $commonStart = [Environment]::GetFolderPath('CommonPrograms')
    $shortcuts = Get-ChildItem $commonStart -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*" -or $_.Name -like "*$bestMatch*" }

    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') } | ForEach-Object {
        $dest = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
        if (Test-Path $dest) {
            foreach ($lnk in $shortcuts) {
                $target = Join-Path $dest $lnk.Name
                if (!(Test-Path $target)) {
                    Copy-Item $lnk.FullName $target -Force -ErrorAction SilentlyContinue
                    Write-Log "  -> Shortcut added for user: $($_.Name)"
                }
            }
        }
    }

    Write-Log "================================================"
    Write-Log "  SUCCESS : '$bestMatch' installed for ALL users"
    Write-Log "  Log saved : $LogFile"
    Write-Log "================================================"
    exit 0
} else {
    Write-Log "================================================"
    Write-Log "  FAILED : exit code $exitCode"
    Write-Log "  Check log: $LogFile"
    Write-Log "================================================"
    exit 1
}