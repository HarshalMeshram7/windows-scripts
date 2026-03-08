# ============================================================
# LOGGING SETUP
# ============================================================

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\parental_control.log"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$time [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
}

function Write-LogSeparator {
    Add-Content -Path $LogFile -Value "========================================"
}

# ============================================================
# ADMIN CHECK
# ============================================================

If (-NOT ([Security.Principal.WindowsPrincipal] `
[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
[Security.Principal.WindowsBuiltInRole] "Administrator")) {

    Write-Error "Please run PowerShell as Administrator."
    exit
}

# ============================================================
# CREATE CHILD USER
# ============================================================

$Username      = "Child"
$PlainPassword = "Child@123"
$Password      = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Write-Warning "User '$Username' already exists."
}
else {

    New-LocalUser `
        -Name $Username `
        -Password $Password `
        -FullName "Child Account" `
        -Description "Standard child account"

    Add-LocalGroupMember -Group "Users" -Member $Username

    Write-Output "User '$Username' created with password '$PlainPassword'."
}

# ============================================================
# STEP 7: BLOCK APPS
# ============================================================

Write-LogSeparator
Write-Log "STEP 7: Blocking browsers and store"

$AppNames = @(
"store"
"chrome"
"msedge"
"firefox"
"brave"
"opera"
"vivaldi"
"iexplore"
"tor"
)

$AppNames = $AppNames |
ForEach-Object { $_.Trim().Trim(',') } |
Where-Object { $_ -ne "" }

Write-Log "Cleaned app list: $($AppNames -join ', ')"

$blockedExe = @()
$foundApps  = @()

$DebuggerPath = "mshta.exe `"javascript:alert('This application has been blocked by your administrator.');close();`""

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "        Auto-Detecting App Types        " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

# ============================================================
# DETECT APP TYPES
# ============================================================

foreach ($app in $AppNames) {

    $pkg = Get-AppxPackage |
    Where-Object { $_.Name -like "*$app*" } |
    Select-Object -First 1

    if ($pkg) {

        Write-Host "  [STORE]  Detected: $($pkg.Name)" -ForegroundColor Cyan
        Write-Log "Detected STORE app $($pkg.Name)"

        $foundApps += $pkg.Name
    }
    else {

        Write-Host "  [EXE]    Detected: $app" -ForegroundColor Yellow
        Write-Log "Detected EXE $app"

        $blockedExe += $app
    }
}

# ============================================================
# BLOCK EXE APPS
# ============================================================

if ($blockedExe.Count -gt 0) {

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "   Blocking EXE Apps via Registry..." -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

foreach ($app in $blockedExe) {

    $exeName = "$app.exe"

    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

    try {

        New-Item -Path $RegPath -Force | Out-Null

        New-ItemProperty `
            -Path $RegPath `
            -Name "Debugger" `
            -PropertyType String `
            -Value $DebuggerPath `
            -Force | Out-Null

        Write-Host "  BLOCKED (EXE): $exeName" -ForegroundColor Red
        Write-Log "Blocked EXE $exeName"
    }
    catch {

        Write-Log "Failed blocking $exeName"
    }
}

}

# ============================================================
# BLOCK STORE APPS
# ============================================================

if ($foundApps.Count -gt 0) {

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Blocking Store Apps via AppLocker..." -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$allowRuleId = [guid]::NewGuid()

$rulesXml = @"
<FilePublisherRule Id="$allowRuleId"
Name="AllowAllApps"
Description="Allow all signed packaged apps"
UserOrGroupSid="S-1-1-0"
Action="Allow">

<Conditions>

<FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">

<BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />

</FilePublisherCondition>

</Conditions>

</FilePublisherRule>
"@

foreach ($productName in $foundApps) {

$ruleId = [guid]::NewGuid()

$rulesXml += @"

<FilePublisherRule Id="$ruleId"
Name="Block $productName"
Description="Block $productName"
UserOrGroupSid="S-1-1-0"
Action="Deny">

<Conditions>

<FilePublisherCondition PublisherName="*" ProductName="$productName" BinaryName="*">

<BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />

</FilePublisherCondition>

</Conditions>

</FilePublisherRule>
"@

}

$policy = @"

<AppLockerPolicy Version="1">

<RuleCollection Type="Appx" EnforcementMode="Enabled">

$rulesXml

</RuleCollection>

</AppLockerPolicy>

"@

$policyPath = "C:\AppLockerPolicy.xml"

$policy | Out-File $policyPath -Encoding UTF8

Set-AppLockerPolicy -XmlPolicy $policyPath -Merge

sc.exe config AppIDSvc start= auto | Out-Null
sc.exe start AppIDSvc | Out-Null

}

# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "             BLOCK SUMMARY              " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($blockedExe.Count -gt 0) {

Write-Host ""
Write-Host "EXE Apps Blocked:" -ForegroundColor Yellow

$blockedExe | ForEach-Object {
Write-Host "  - $_.exe" -ForegroundColor Red
}

}

if ($foundApps.Count -gt 0) {

Write-Host ""
Write-Host "Store Apps Blocked:" -ForegroundColor Yellow

$foundApps | Sort-Object -Unique | ForEach-Object {
Write-Host "  - $_" -ForegroundColor Red
}

}

Write-Host ""
Write-Host "---- Completed Blocking Applications ----" -ForegroundColor Green

# ============================================================
# SIGN OUT
# ============================================================

Write-Output "Signing out current user..."
shutdown.exe /l