# Remove-InstallRestrictions.ps1
# Removes all install AND uninstall restrictions for user "Child"
# Automatically signs the user out at the END
# Run as Administrator
#Requires -RunAsAdministrator

$Username = "Child"

$user = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
if (-not $user) {
    Write-Host "[ERROR] User '$Username' not found." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Removing All Restrictions for: $Username"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$UserProfile = "C:\Users\$Username"

# Helper: restore execute permission on a system EXE
function Restore-Execute {
    param([string]$ExePath, [string]$User, [string]$Label)

    if (-not (Test-Path $ExePath)) {
        Write-Host "    SKIP - $Label not found" -ForegroundColor DarkGray
        return
    }

    $acl = Get-Acl -Path $ExePath
    $denyRules = $acl.Access | Where-Object {
        $_.IdentityReference.Value -like "*$User*" -and
        $_.AccessControlType -eq "Deny"
    }

    if ($denyRules) {
        foreach ($rule in $denyRules) { $acl.RemoveAccessRule($rule) | Out-Null }
        Set-Acl -Path $ExePath -AclObject $acl -ErrorAction SilentlyContinue
        Write-Host "    OK - $Label restored" -ForegroundColor Green
    } else {
        Write-Host "    SKIP - No deny rules on $Label" -ForegroundColor DarkGray
    }
}

# ----------------------------------------------------------------
# STEP 1 - Re-enable MSI installs and uninstalls via policy
# ----------------------------------------------------------------
Write-Host "[1/10] Re-enabling MSI install/uninstall via policy..." -ForegroundColor Yellow
$p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"

if (Test-Path $p) {
    Remove-ItemProperty $p -Name "DisableMSI","DisableUserInstalls","DisablePatch" -Force -ErrorAction SilentlyContinue
    if ((Get-Item $p).Property.Count -eq 0) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK" -ForegroundColor Green
} else {
    Write-Host "    SKIP - Key not found" -ForegroundColor DarkGray
}

# ----------------------------------------------------------------
# STEP 2 - Restore MsiExec.exe and wusa.exe permissions
# ----------------------------------------------------------------
Write-Host "[2/10] Restoring MsiExec.exe and wusa.exe permissions..." -ForegroundColor Yellow
Restore-Execute "$env:SystemRoot\System32\MsiExec.exe" $Username "MsiExec.exe (System32)"
Restore-Execute "$env:SystemRoot\SysWOW64\MsiExec.exe" $Username "MsiExec.exe (SysWOW64)"
Restore-Execute "$env:SystemRoot\System32\wusa.exe"    $Username "wusa.exe"

# ----------------------------------------------------------------
# STEP 3 - Remove Software Restriction Policies
# ----------------------------------------------------------------
Write-Host "[3/10] Removing Software Restriction Policies..." -ForegroundColor Yellow
$srp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"
$srpPaths = "$srp\0\Paths"

if (Test-Path $srpPaths) {
    Get-ChildItem $srpPaths | ForEach-Object {
        $desc = (Get-ItemProperty $_.PSPath -Name "Description" -ErrorAction SilentlyContinue).Description
        if ($desc -eq "Blocked by InstallRestrictions script") {
            Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if (Test-Path $srp) {
    Remove-ItemProperty $srp -Name "DefaultLevel","PolicyScope","TransparentEnabled","ExecutableTypes" -Force -ErrorAction SilentlyContinue
    Write-Host "    OK" -ForegroundColor Green
}

# ----------------------------------------------------------------
# STEP 4 - Restore Temp and Downloads permissions
# ----------------------------------------------------------------
Write-Host "[4/10] Restoring Temp and Downloads folder permissions..." -ForegroundColor Yellow

$folders = @("$UserProfile\AppData\Local\Temp", "$UserProfile\Downloads")

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        $acl = Get-Acl $folder
        $denyRules = $acl.Access | Where-Object {
            $_.IdentityReference.Value -like "*$Username*" -and
            $_.AccessControlType -eq "Deny"
        }

        foreach ($rule in $denyRules) { $acl.RemoveAccessRule($rule) | Out-Null }
        Set-Acl $folder $acl
        Write-Host "    OK - Restored: $folder" -ForegroundColor Green
    }
}

# ----------------------------------------------------------------
# STEP 5 - Re-enable Microsoft Store
# ----------------------------------------------------------------
Write-Host "[5/10] Re-enabling Microsoft Store..." -ForegroundColor Yellow
$store = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"

if (Test-Path $store) {
    Remove-ItemProperty $store -Name "DisableStoreApps","AutoDownload","RemoveWindowsStore" -Force -ErrorAction SilentlyContinue
    if ((Get-Item $store).Property.Count -eq 0) { Remove-Item $store -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK" -ForegroundColor Green
}

# ----------------------------------------------------------------
# STEP 6 - Restore uninstall registry access
# ----------------------------------------------------------------
Write-Host "[6/10] Restoring Uninstall registry key access..." -ForegroundColor Yellow
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($uKey in $uninstallKeys) {
    if (Test-Path $uKey) {
        $acl = Get-Acl $uKey
        $denyRules = $acl.Access | Where-Object {
            $_.IdentityReference.Value -like "*$Username*" -and
            $_.AccessControlType -eq "Deny"
        }
        foreach ($rule in $denyRules) { $acl.RemoveAccessRule($rule) | Out-Null }
        Set-Acl $uKey $acl
    }
}

Write-Host "    OK" -ForegroundColor Green

# ----------------------------------------------------------------
# STEP 7 - Clean user registry hive
# ----------------------------------------------------------------
Write-Host "[7/10] Cleaning user registry hive..." -ForegroundColor Yellow
$hivePath = "$UserProfile\NTUSER.DAT"

if (Test-Path $hivePath) {
    $hiveKey = "HKU\RESTRICT_$Username"
    reg load $hiveKey $hivePath 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {

        $keys = @(
            "Registry::$hiveKey\Software\Policies\Microsoft",
            "Registry::$hiveKey\Software\Microsoft\Windows\CurrentVersion\Policies"
        )

        foreach ($k in $keys) {
            if (Test-Path $k) {
                Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        reg unload $hiveKey 2>&1 | Out-Null
        Write-Host "    OK" -ForegroundColor Green
    }
}

# ----------------------------------------------------------------
# STEP 8 - Remove AppLocker rules
# ----------------------------------------------------------------
Write-Host "[8/10] Cleaning AppLocker rules..." -ForegroundColor Yellow
$userSID = (Get-LocalUser -Name $Username).SID.Value
$currentPolicy = Get-AppLockerPolicy -Local -ErrorAction SilentlyContinue

if ($currentPolicy) {
    $xml = Get-AppLockerPolicy -Local -Xml
    $xmlObj = [xml]$xml
    $nodes = $xmlObj.SelectNodes("//*[@UserOrGroupSid='$userSID']")

    foreach ($node in $nodes) {
        $node.ParentNode.RemoveChild($node) | Out-Null
    }

    if ($nodes.Count -gt 0) {
        $tempXml = "$env:TEMP\AppLockerClean.xml"
        $xmlObj.Save($tempXml)
        Set-AppLockerPolicy -XmlPolicy $tempXml -ErrorAction SilentlyContinue
        Remove-Item $tempXml -Force -ErrorAction SilentlyContinue
        Write-Host "    OK - Removed $($nodes.Count) rules" -ForegroundColor Green
    }
}

# ----------------------------------------------------------------
# STEP 9 - Refresh Group Policy
# ----------------------------------------------------------------
Write-Host "[9/10] Refreshing Group Policy..." -ForegroundColor Yellow
gpupdate /force 2>&1 | Out-Null
Write-Host "    OK" -ForegroundColor Green

# ----------------------------------------------------------------
# STEP 10 - Force user sign out (NEW)
# ----------------------------------------------------------------
Write-Host "[10/10] Forcing '$Username' to sign out..." -ForegroundColor Yellow

$session = quser 2>$null | Where-Object { $_ -match "^\s*$Username\s" }

if ($session) {
    $sessionId = ($session -split '\s+')[2]

    if ($sessionId -match '^\d+$') {
        logoff $sessionId /V 2>&1 | Out-Null
        Write-Host "    OK - Session $sessionId logged off." -ForegroundColor Green
    }
    else {
        Get-WmiObject Win32_Process |
            Where-Object { $_.GetOwner().User -eq $Username } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

        Write-Host "    OK - User processes terminated." -ForegroundColor Green
    }
}
else {
    Write-Host "    User not currently logged in." -ForegroundColor DarkGray
}

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SUCCESS - All restrictions removed and user signed out"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""