# ==============================================================
#  Remove-Safe4Sure.ps1
#  Removes Safe4Sure / SafeBrowser apps, services, and user
#  Run as Administrator in PowerShell
# ==============================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param($msg) Write-Host "`n[*] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "    [--] $msg" -ForegroundColor Yellow }


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

# --------------------------------------------------------------
# 1. STOP AND DELETE SERVICES
# --------------------------------------------------------------
Write-Step "Stopping and removing services..."

$services = @("S4SApp", "Safe4SureInstaller")

foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        & sc.exe delete $svc | Out-Null
        Write-OK "Service '$svc' stopped and deleted."
    } else {
        Write-Warn "Service '$svc' not found - skipping."
    }
}

# --------------------------------------------------------------
# 2. KILL RUNNING APP PROCESSES
# --------------------------------------------------------------
Write-Step "Killing app processes if running..."

$processNames = @("ManagedBrowser", "MDMApp")

foreach ($proc in $processNames) {
    $p = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($p) {
        Stop-Process -Name $proc -Force
        Write-OK "Killed process: $proc"
    } else {
        Write-Warn "Process not running: $proc"
    }
}

# --------------------------------------------------------------
# 3. REMOVE UWP / APPX PACKAGES
# --------------------------------------------------------------
Write-Step "Removing UWP/AppX packages..."

$packageFamilies = @(
    "com.safe4sure.safebrowser_fpmp3vg97j7wc",
    "com.companyname.mdmapp_fpmp3vg97j7wc"
)

foreach ($family in $packageFamilies) {
    # Remove for all users
    $pkgs = Get-AppxPackage -AllUsers | Where-Object { $_.PackageFamilyName -eq $family }
    if ($pkgs) {
        foreach ($pkg in $pkgs) {
            Write-OK "Removing package: $($pkg.PackageFullName)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    } else {
        Write-Warn "AppX package not found for family: $family"
    }

    # Remove provisioned package (prevents reinstall on new users)
    $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$($family.Split('_')[0])*" }
    if ($prov) {
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
        Write-OK "Removed provisioned package: $($prov.PackageName)"
    }
}

# --------------------------------------------------------------
# 4. FORCE DELETE WINDOWSAPPS FOLDERS (Take Ownership)
# --------------------------------------------------------------
Write-Step "Force removing WindowsApps folders..."

$appFolders = @(
    "C:\Program Files\WindowsApps\com.safe4sure.safebrowser_2.0.0.2_x64__fpmp3vg97j7wc",
    "C:\Program Files\WindowsApps\com.companyname.mdmapp_0.0.2.0_x64__fpmp3vg97j7wc"
)

foreach ($folder in $appFolders) {
    if (Test-Path $folder) {
        Write-OK "Taking ownership of: $folder"
        # Take ownership
        & takeown /F $folder /R /D Y | Out-Null
        # Grant full control to Administrators
        & icacls $folder /grant "Administrators:F" /T /C | Out-Null
        # Delete
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $folder)) {
            Write-OK "Deleted folder: $folder"
        } else {
            Write-Warn "Could not delete (may need reboot): $folder"
        }
    } else {
        Write-Warn "Folder not found (already removed?): $folder"
    }
}

# --------------------------------------------------------------
# 5. UNINSTALL VIA REGISTRY (MSI/NSIS fallback)
# --------------------------------------------------------------
Write-Step "Checking registry for traditional uninstall entries..."

$appNames = @("Safe4Sure", "SafeBrowser", "ManagedBrowser", "MDMApp", "S4S")

$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($app in $appNames) {
    foreach ($path in $regPaths) {
        $entry = Get-ItemProperty $path -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -like "*$app*" }
        if ($entry) {
            $uninstallStr = $entry.UninstallString
            Write-OK "Found '$($entry.DisplayName)' - running uninstaller..."
            if ($uninstallStr -match "msiexec") {
                $productCode = ($uninstallStr -replace ".*({.*})", '$1').Trim()
                Start-Process "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait
            } else {
                $exe = ($uninstallStr -split '"')[1]
                $silentArgs = '/S /SILENT /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
                if (Test-Path $exe) {
                    Start-Process -FilePath $exe -ArgumentList $silentArgs -Wait
                } else {
                    cmd /c "$uninstallStr /S" | Out-Null
                }
            }
            Write-OK "'$app' uninstalled via registry."
        }
    }
}

# --------------------------------------------------------------
# 6. DELETE OTHER LEFTOVER FILES AND FOLDERS
# --------------------------------------------------------------
Write-Step "Removing leftover app data..."

$foldersToDelete = @(
    "$env:ProgramFiles\Safe4Sure",
    "$env:ProgramFiles\SafeBrowser",
    "${env:ProgramFiles(x86)}\Safe4Sure",
    "${env:ProgramFiles(x86)}\SafeBrowser",
    "$env:LocalAppData\Safe4Sure",
    "$env:LocalAppData\SafeBrowser",
    "$env:AppData\Safe4Sure",
    "$env:AppData\SafeBrowser",
    "$env:LocalAppData\Packages\com.safe4sure.safebrowser_fpmp3vg97j7wc",
    "$env:LocalAppData\Packages\com.companyname.mdmapp_fpmp3vg97j7wc"
)

foreach ($folder in $foldersToDelete) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force
        Write-OK "Deleted: $folder"
    } else {
        Write-Warn "Not found: $folder"
    }
}

# --------------------------------------------------------------
# 7. CLEAN UP REGISTRY KEYS
# --------------------------------------------------------------
Write-Step "Cleaning registry entries..."

$regKeysToDelete = @(
    "HKLM:\SOFTWARE\Safe4Sure",
    "HKLM:\SOFTWARE\SafeBrowser",
    "HKLM:\SOFTWARE\WOW6432Node\Safe4Sure",
    "HKLM:\SOFTWARE\WOW6432Node\SafeBrowser",
    "HKCU:\SOFTWARE\Safe4Sure",
    "HKCU:\SOFTWARE\SafeBrowser"
)

foreach ($key in $regKeysToDelete) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-OK "Deleted registry key: $key"
    } else {
        Write-Warn "Registry key not found: $key"
    }
}



# --------------------------------------------------------------
# 9. BROWSER UNBLOCK - PLACEHOLDER (paste your script here)
# --------------------------------------------------------------
# Run as Administrator
# This script automatically finds and removes ALL app blocks

$unblockedExe   = @()
$unblockedStore = @()

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "     Scanning System For Blocked Apps    " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# ============================================================
# PART 1: Find and Unblock EXE Apps (Registry Debugger Method)
# ============================================================

Write-Host "Checking EXE blocks in registry..." -ForegroundColor Cyan

$baseRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

Get-ChildItem $baseRegPath | ForEach-Object {

    $exeName = $_.PSChildName
    $regPath = "$baseRegPath\$exeName"

    $debugger = Get-ItemProperty -Path $regPath -Name "Debugger" -ErrorAction SilentlyContinue

    if ($debugger) {

        Write-Host "  BLOCK FOUND: $exeName" -ForegroundColor Red

        Remove-ItemProperty -Path $regPath -Name "Debugger" -Force
        Write-Host "  UNBLOCKED (EXE): $exeName" -ForegroundColor Green

        $remaining = Get-Item -Path $regPath | Select-Object -ExpandProperty Property
        if ($remaining.Count -eq 0) {
            Remove-Item -Path $regPath -Force
        }

        $unblockedExe += $exeName
    }
}

if ($unblockedExe.Count -eq 0) {
    Write-Host "  No EXE apps were blocked." -ForegroundColor Yellow
}

# ============================================================
# PART 2: Find and Remove AppLocker Deny Rules (Store Apps)
# ============================================================

Write-Host "`nChecking AppLocker rules..." -ForegroundColor Cyan

$currentPolicyXml = Get-AppLockerPolicy -Effective -Xml
[xml]$policyDoc = $currentPolicyXml

$ruleCollections = $policyDoc.AppLockerPolicy.RuleCollection

foreach ($collection in $ruleCollections) {

    $denyRules = $collection.FilePublisherRule | Where-Object { $_.Action -eq "Deny" }

    foreach ($rule in $denyRules) {

        Write-Host "  Removing rule: $($rule.Name)" -ForegroundColor Red

        $collection.RemoveChild($rule) | Out-Null

        $unblockedStore += $rule.Name
    }
}

if ($unblockedStore.Count -gt 0) {

    $cleanedPolicyPath = "C:\AppLockerPolicy_Cleaned.xml"
    $policyDoc.Save($cleanedPolicyPath)

    Write-Host "`nApplying cleaned AppLocker policy..." -ForegroundColor Cyan
    Set-AppLockerPolicy -XmlPolicy $cleanedPolicyPath

    sc.exe stop AppIDSvc | Out-Null
    Start-Sleep -Seconds 2
    sc.exe start AppIDSvc | Out-Null

    Write-Host "AppLocker refreshed!" -ForegroundColor Green
}
else {
    Write-Host "  No AppLocker deny rules found." -ForegroundColor Yellow
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "            UNBLOCK SUMMARY             " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($unblockedExe.Count -gt 0) {
    Write-Host "`nEXE Apps Unblocked:" -ForegroundColor Yellow
    $unblockedExe | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
}

if ($unblockedStore.Count -gt 0) {
    Write-Host "`nStore Apps / AppLocker Rules Removed:" -ForegroundColor Yellow
    $unblockedStore | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
}

if ($unblockedExe.Count -eq 0 -and $unblockedStore.Count -eq 0) {
    Write-Host "`nNo blocks were detected on this system." -ForegroundColor Yellow
}

Write-Host "`n---- Completed Unblocking All Applications ----`n" -ForegroundColor Green


#####################################################################################################
#################################################################################################
#Enable media storage
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 3

Write-Host "USB storage devices are enabled again." -ForegroundColor Green

# --------------------------------------------------------------
# 8. DELETE LOCAL USER ACCOUNT 'Child'
# --------------------------------------------------------------
Write-Step "Removing local user account 'Child'..."

$childUser = Get-LocalUser -Name "Child" -ErrorAction SilentlyContinue
if ($childUser) {
    $sessions = query session 2>$null | Select-String "Child"
    if ($sessions) {
        $sessionId = ($sessions -split "\s+")[2]
        logoff $sessionId /server:localhost 2>$null
        Write-Warn "Logged off active session for 'Child'."
    }
    Remove-LocalUser -Name "Child"
    Write-OK "User account 'Child' deleted."
    $profilePath = "C:\Users\Child"
    if (Test-Path $profilePath) {
        Remove-Item -Path $profilePath -Recurse -Force
        Write-OK "Profile folder '$profilePath' deleted."
    }
} else {
    Write-Warn "Local user 'Child' not found - skipping."
}