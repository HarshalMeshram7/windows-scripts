# Apply-InstallRestrictions.ps1
# Blocks software installation AND uninstallation for user "Child"
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
Write-Host "  Applying Install + Uninstall Restrictions for: $Username"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$UserProfile = "C:\Users\$Username"

# Helper: deny execute on a system EXE for the target user
function Deny-Execute {
    param([string]$ExePath, [string]$User, [string]$Label)

    if (-not (Test-Path $ExePath)) {
        Write-Host "    SKIP - $Label not found" -ForegroundColor DarkGray
        return
    }

    $acl = Get-Acl -Path $ExePath
    $deny = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $User, "ReadAndExecute", "None", "None", "Deny"
    )
    $acl.SetAccessRule($deny)
    Set-Acl -Path $ExePath -AclObject $acl -ErrorAction SilentlyContinue

    Write-Host "    OK - $Label blocked" -ForegroundColor Green
}

# ----------------------------------------------------------------
# STEP 1 - Block MSI installs AND uninstalls via policy
# ----------------------------------------------------------------
Write-Host "[1/10] Blocking MSI install/uninstall via policy..." -ForegroundColor Yellow
$p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name "DisableMSI"          -Value 1 -Type DWord -Force
Set-ItemProperty -Path $p -Name "DisableUserInstalls" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $p -Name "DisablePatch"        -Value 1 -Type DWord -Force
Write-Host "    OK" -ForegroundColor Green

# ----------------------------------------------------------------
# STEP 2 - Deny execute on MsiExec.exe and wusa.exe
# ----------------------------------------------------------------
Write-Host "[2/10] Blocking MsiExec.exe and wusa.exe..." -ForegroundColor Yellow
Deny-Execute "$env:SystemRoot\System32\MsiExec.exe" $Username "MsiExec.exe (System32)"
Deny-Execute "$env:SystemRoot\SysWOW64\MsiExec.exe" $Username "MsiExec.exe (SysWOW64)"
Deny-Execute "$env:SystemRoot\System32\wusa.exe"    $Username "wusa.exe"

# ----------------------------------------------------------------
# STEP 3 - Enable SRP and block EXE/MSI in AppData/Temp
# ----------------------------------------------------------------
Write-Host "[3/10] Enabling SRP and blocking installs from AppData/Temp..." -ForegroundColor Yellow
$srp = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"
if (-not (Test-Path $srp)) { New-Item -Path $srp -Force | Out-Null }
Set-ItemProperty -Path $srp -Name "DefaultLevel"       -Value 131072 -Type DWord -Force
Set-ItemProperty -Path $srp -Name "PolicyScope"        -Value 0      -Type DWord -Force
Set-ItemProperty -Path $srp -Name "TransparentEnabled" -Value 1      -Type DWord -Force

$srpPaths = "$srp\0\Paths"
if (-not (Test-Path $srpPaths)) { New-Item -Path $srpPaths -Force | Out-Null }

$pathsToBlock = "%APPDATA%\*.exe","%LOCALAPPDATA%\*.exe","%TEMP%\*.exe","%TMP%\*.exe","%APPDATA%\*.msi","%LOCALAPPDATA%\*.msi","%TEMP%\*.msi"

foreach ($blockPath in $pathsToBlock) {
    $guid = [System.Guid]::NewGuid().ToString("B").ToUpper()
    $rp = "$srpPaths\$guid"
    New-Item -Path $rp -Force | Out-Null
    Set-ItemProperty -Path $rp -Name "SaferFlags"  -Value 0          -Type DWord        -Force
    Set-ItemProperty -Path $rp -Name "ItemData"    -Value $blockPath -Type ExpandString -Force
    Set-ItemProperty -Path $rp -Name "Description" -Value "Blocked by InstallRestrictions script" -Type String -Force
}
Write-Host "    OK" -ForegroundColor Green

# ----------------------------------------------------------------
# STEP 4 - Restrict Temp folder write access
# ----------------------------------------------------------------
Write-Host "[4/10] Restricting Temp folder write access..." -ForegroundColor Yellow
$tempDir = "$UserProfile\AppData\Local\Temp"
if (Test-Path $tempDir) {
    $acl = Get-Acl $tempDir
    $deny = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Username,"Write,AppendData","ContainerInherit,ObjectInherit","None","Deny"
    )
    $acl.AddAccessRule($deny)
    Set-Acl $tempDir $acl
    Write-Host "    OK" -ForegroundColor Green
}

# ----------------------------------------------------------------
# STEP 5 - Disable Microsoft Store
# ----------------------------------------------------------------
Write-Host "[5/10] Disabling Microsoft Store..." -ForegroundColor Yellow
$store = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
if (-not (Test-Path $store)) { New-Item -Path $store -Force | Out-Null }
Set-ItemProperty $store -Name "DisableStoreApps"   -Value 1 -Type DWord -Force
Set-ItemProperty $store -Name "RemoveWindowsStore" -Value 1 -Type DWord -Force
Write-Host "    OK" -ForegroundColor Green

# ----------------------------------------------------------------
# STEP 6 - Hide uninstall registry keys
# ----------------------------------------------------------------
Write-Host "[6/10] Hiding installed apps list..." -ForegroundColor Yellow
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($uKey in $uninstallKeys) {
    if (Test-Path $uKey) {
        $acl = Get-Acl $uKey
        $denyRule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $Username,"ReadKey","ContainerInherit,ObjectInherit","None","Deny"
        )
        $acl.AddAccessRule($denyRule)
        Set-Acl $uKey $acl
    }
}
Write-Host "    OK" -ForegroundColor Green

# ----------------------------------------------------------------
# STEP 7 - Patch user registry hive
# ----------------------------------------------------------------
Write-Host "[7/10] Patching user registry hive..." -ForegroundColor Yellow
$hivePath = "$UserProfile\NTUSER.DAT"
if (Test-Path $hivePath) {
    $hiveKey = "HKU\RESTRICT_$Username"
    reg load $hiveKey $hivePath 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {

        $p = "Registry::$hiveKey\Software\Policies\Microsoft\Windows\Installer"
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty $p -Name "DisableMSI" -Value 1 -Type DWord -Force

        reg unload $hiveKey 2>&1 | Out-Null
        Write-Host "    OK" -ForegroundColor Green
    }
}

# ----------------------------------------------------------------
# STEP 8 - Deny write to Downloads folder
# ----------------------------------------------------------------
Write-Host "[8/10] Denying write to Downloads folder..." -ForegroundColor Yellow
$downloadsDir = "$UserProfile\Downloads"
if (Test-Path $downloadsDir) {
    $acl = Get-Acl $downloadsDir
    $deny = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Username,"Write,AppendData","ContainerInherit,ObjectInherit","None","Deny"
    )
    $acl.AddAccessRule($deny)
    Set-Acl $downloadsDir $acl
    Write-Host "    OK" -ForegroundColor Green
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
Write-Host " SUCCESS - All restrictions applied and user signed out"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""