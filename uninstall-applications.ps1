# Run as Administrator
# Usage: .\uninstall-applications.ps1 slack

param(
    [Parameter(Mandatory=$true)]
    [string]$AppName
)

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\uninstall_$AppName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    switch ($Level) {
        "INFO"    { Write-Host $line -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $line -ForegroundColor Green }
        "WARN"    { Write-Host $line -ForegroundColor Yellow }
        "ERROR"   { Write-Host $line -ForegroundColor Red }
    }
}

Write-Log "=== START === Target: $AppName"
Write-Log "PS $($PSVersionTable.PSVersion) | User: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"

# ---------------------------------------------------------------
# STEP 0: Kill matching processes
# ---------------------------------------------------------------
Write-Log "STEP 0: Killing processes..."
$procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*" }
foreach ($p in $procs) {
    Write-Log "  Killing $($p.Name) PID=$($p.Id)" "WARN"
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    Write-Log "  Killed $($p.Name)" "SUCCESS"
}

# ---------------------------------------------------------------
# STEP 1: AppX / Store app
# ---------------------------------------------------------------
Write-Log "STEP 1: Store apps..."
$store = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*" }
foreach ($a in $store) {
    Write-Log "  Removing $($a.PackageFullName)"
    try {
        Remove-AppxPackage -Package $a.PackageFullName -AllUsers -ErrorAction Stop
        Write-Log "  Removed $($a.PackageFullName)" "SUCCESS"
    } catch {
        Write-Log "  Failed: $_" "ERROR"
    }
}
if (-not $store) { Write-Log "  No Store apps found" "WARN" }

# ---------------------------------------------------------------
# STEP 2: Winget
# ---------------------------------------------------------------
Write-Log "STEP 2: Winget..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wOut = winget uninstall --name $AppName --silent --force --accept-source-agreements 2>&1
    Write-Log "  Winget output: $wOut"
    if ($LASTEXITCODE -eq 0) { Write-Log "  Winget succeeded" "SUCCESS" }
    else { Write-Log "  Winget exit=$LASTEXITCODE" "WARN" }
} else {
    Write-Log "  Winget not available" "WARN"
}

# ---------------------------------------------------------------
# STEP 3: Chocolatey
# ---------------------------------------------------------------
Write-Log "STEP 3: Chocolatey..."
if (Get-Command choco -ErrorAction SilentlyContinue) {
    $cOut = choco uninstall $AppName -y --force 2>&1
    Write-Log "  Choco output: $cOut"
    if ($LASTEXITCODE -eq 0) { Write-Log "  Choco succeeded" "SUCCESS" }
    else { Write-Log "  Choco exit=$LASTEXITCODE" "WARN" }
} else {
    Write-Log "  Chocolatey not available" "WARN"
}

# ---------------------------------------------------------------
# STEP 4: Registry EXE/MSI uninstall
# Popup dismisser: pure PowerShell background job using
# WScript.Shell SendKeys -- no C#, no Add-Type, no compilation
# ---------------------------------------------------------------
Write-Log "STEP 4: Registry uninstall..."

function Start-PopupWatcher {
    $job = Start-Job -ScriptBlock {
        $shell = New-Object -ComObject WScript.Shell
        $end   = (Get-Date).AddSeconds(120)
        while ((Get-Date) -lt $end) {
            $wins = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }
            foreach ($w in $wins) {
                $t = $w.MainWindowTitle.ToLower()
                $isDialog = ($t -like "*uninstall*") -or ($t -like "*confirm*") -or ($t -like "*warning*") -or ($t -like "*remove*")
                if ($isDialog) {
                    $null = $shell.AppActivate($w.Id)
                    Start-Sleep -Milliseconds 150
                    $shell.SendKeys("{ENTER}")
                }
            }
            Start-Sleep -Milliseconds 400
        }
    }
    return $job
}

$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$found = $false
foreach ($rp in $regPaths) {
    $entries = Get-ItemProperty $rp -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$AppName*" }
    foreach ($entry in $entries) {
        $found = $true
        Write-Log "  Found: $($entry.DisplayName)"

        $uStr = $entry.QuietUninstallString
        if (-not $uStr) { $uStr = $entry.UninstallString }
        if (-not $uStr) { Write-Log "  No uninstall string, skipping" "WARN"; continue }

        Write-Log "  Uninstall string: $uStr"

        if ($uStr -match "msiexec") {
            # Extract MSI product code safely -- no inline regex with special chars
            $null = $uStr -match '\{[A-F0-9\-]+\}'
            $code = $Matches[0]
            Write-Log "  MSI code: $code"
            Start-Process "msiexec.exe" -ArgumentList "/x $code /qn /norestart" -Wait -WindowStyle Hidden
            Write-Log "  MSI done: $($entry.DisplayName)" "SUCCESS"
        } else {
            if ($uStr -match '"') {
                $exePath = ($uStr -split '"')[1]
            } else {
                $exePath = ($uStr -split ' ')[0]
            }
            Write-Log "  EXE: $exePath"
            if (-not (Test-Path $exePath -ErrorAction SilentlyContinue)) {
                Write-Log "  EXE not found: $exePath" "WARN"
                continue
            }
            Write-Log "  Starting popup watcher..."
            $wJob = Start-PopupWatcher
            Start-Process -FilePath $exePath -ArgumentList "/S /silent /verysilent /quiet /norestart" -Wait -WindowStyle Normal
            Stop-Job  -Job $wJob -ErrorAction SilentlyContinue
            Remove-Job -Job $wJob -Force -ErrorAction SilentlyContinue
            Write-Log "  EXE done: $($entry.DisplayName)" "SUCCESS"
        }
    }
}
if (-not $found) { Write-Log "  Not found in registry" "WARN" }

# ---------------------------------------------------------------
# STEP 5: Delete leftover folders
# ---------------------------------------------------------------
Write-Log "STEP 5: Leftover folders..."
$roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA, $env:LOCALAPPDATA)
foreach ($root in $roots) {
    if (-not $root) { continue }
    if (-not (Test-Path $root)) { continue }
    $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*" }
    foreach ($d in $dirs) {
        Write-Log "  Removing $($d.FullName)" "WARN"
        try {
            & takeown /f "$($d.FullName)" /r /d y 2>&1 | Out-Null
            & icacls "$($d.FullName)" /grant "$($env:USERNAME):F" /t /q 2>&1 | Out-Null
            Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction Stop
            Write-Log "  Deleted $($d.FullName)" "SUCCESS"
        } catch {
            Write-Log "  Could not delete $($d.FullName): $_" "ERROR"
        }
    }
}

# ---------------------------------------------------------------
# STEP 6: Remove leftover registry keys
# ---------------------------------------------------------------
Write-Log "STEP 6: Leftover registry keys..."
$regRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($root in $regRoots) {
    $keys = Get-ChildItem -Path $root -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName -like "*$AppName*"
    }
    foreach ($k in $keys) {
        Write-Log "  Removing key $($k.PSPath)" "WARN"
        try {
            Remove-Item -Path $k.PSPath -Recurse -Force -ErrorAction Stop
            Write-Log "  Removed $($k.PSPath)" "SUCCESS"
        } catch {
            Write-Log "  Failed $($k.PSPath): $_" "ERROR"
        }
    }
}

# ---------------------------------------------------------------
# STEP 7: Remove leftover shortcuts
# ---------------------------------------------------------------
Write-Log "STEP 7: Leftover shortcuts..."
$lnkRoots = @(
    "$env:PUBLIC\Desktop",
    "$env:USERPROFILE\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
)
foreach ($dir in $lnkRoots) {
    if (-not (Test-Path $dir)) { continue }
    $links = Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$AppName*" }
    foreach ($lnk in $links) {
        Write-Log "  Removing $($lnk.FullName)" "WARN"
        try {
            Remove-Item -Path $lnk.FullName -Force -ErrorAction Stop
            Write-Log "  Removed $($lnk.FullName)" "SUCCESS"
        } catch {
            Write-Log "  Failed: $_" "ERROR"
        }
    }
}

Write-Log "=== DONE === Log: $LogFile" "SUCCESS"