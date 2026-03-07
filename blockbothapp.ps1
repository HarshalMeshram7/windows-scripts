# Run as Administrator
# Usage: .\block-apps.ps1 chrome, postman, Teams, Xbox, Outlook, Notepad

param (
    [Parameter(Mandatory = $true)]
    [string[]]$AppNames
)

# ============================================================
# LOGGING SETUP
# ============================================================

$LogDir  = "C:\Logs"
$LogFile = "$LogDir\block-apps_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine   = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $LogFile -Value $logLine

    # Also write to console with colour
    switch ($Level) {
        "INFO"    { Write-Host $logLine -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "WARNING" { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logLine -ForegroundColor Red }
    }
}

# ---- Session header ----
Add-Content -Path $LogFile -Value ""
Add-Content -Path $LogFile -Value "========================================"
Add-Content -Path $LogFile -Value "  block-apps.ps1  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $LogFile -Value "========================================"

Write-Log "Script started. Log file: $LogFile" "INFO"
Write-Log "Raw input app names: $($AppNames -join ', ')" "INFO"

# ============================================================
# CLEAN UP APP NAMES
# ============================================================

$AppNames = $AppNames | ForEach-Object { $_.Trim().Trim(',') } | Where-Object { $_ -ne "" }
Write-Log "Cleaned app names: $($AppNames -join ', ')" "INFO"

$blockedExe   = @()
$blockedStore = @()
$foundApps    = @()


# ============================================================
# CREATE POPUP SCRIPT AUTOMATICALLY
# ============================================================

$PopupScriptPath = "C:\Windows\BlockedAppPopup.ps1"

if (-not (Test-Path $PopupScriptPath)) {

$PopupScript = @'
param($BlockedApp)

Add-Type -AssemblyName PresentationFramework

[System.Windows.MessageBox]::Show(
"This app has been blocked by your administrator.",
"Application Blocked",
"OK",
"Warning"
)
'@

    $PopupScript | Out-File $PopupScriptPath -Encoding UTF8 -Force
}

$DebuggerPath = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Windows\BlockedAppPopup.ps1'

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "        Auto-Detecting App Types        " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta
Write-Log "--- Auto-detecting app types ---" "INFO"

# ============================================================
# DETECT APP TYPES
# ============================================================

foreach ($app in $AppNames) {

    # ---- Check if it's a Store/UWP app first ----
    $pkg = Get-AppxPackage | Where-Object { $_.Name -eq $app } | Select-Object -First 1
    if (-not $pkg) {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like "*$app*" } | Select-Object -First 1
    }

    if ($pkg) {
        Write-Host "  [STORE]  Detected: $($pkg.Name)" -ForegroundColor Cyan
        Write-Log "Detected as STORE app: $($pkg.Name) (input: '$app')" "INFO"
        $foundApps    += $pkg.Name
        $blockedStore += $app
    } else {
        Write-Host "  [EXE]    Detected: $app" -ForegroundColor DarkYellow
        Write-Log "Detected as EXE app: $app" "INFO"
        $blockedExe += $app
    }
}

# ============================================================
# PART 1: Block EXE Apps via Registry
# ============================================================

if ($blockedExe.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "   Blocking EXE Apps via Registry...   " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Log "--- Blocking EXE apps via Registry ---" "INFO"

    foreach ($app in $blockedExe) {
        $cleanName = $app -replace '\.exe$', ''
        $exeName   = "$cleanName.exe"
        $RegPath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

        try {
            New-Item -Path $RegPath -Force | Out-Null
            New-ItemProperty `
                -Path $RegPath `
                -Name "Debugger" `
                -PropertyType String `
                -Value $DebuggerPath `
                -Force | Out-Null

            Write-Host "  BLOCKED (EXE): $exeName" -ForegroundColor Red
            Write-Log "Successfully blocked EXE app via registry: $exeName  |  RegPath: $RegPath" "SUCCESS"
        }
        catch {
            Write-Host "  FAILED to block (EXE): $exeName" -ForegroundColor Red
            Write-Log "Failed to block EXE app '$exeName'. Error: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ============================================================
# PART 2: Block Store Apps via AppLocker
# ============================================================

if ($foundApps.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Blocking Store Apps via AppLocker...  " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Log "--- Blocking Store apps via AppLocker ---" "INFO"

    Write-Host "`nGenerating AppLocker rules..." -ForegroundColor Cyan
    Write-Log "Generating AppLocker rules for $($foundApps.Count) app(s)..." "INFO"

    # Allow All rule (required)
    $allowRuleId = [System.Guid]::NewGuid().ToString()
    Write-Log "Generated Allow-All rule UUID: $allowRuleId" "INFO"

    $rulesXml = @"
    <!-- Allow All (Required) -->
    <FilePublisherRule Id="$allowRuleId"
      Name="Allow All Signed Packaged Apps"
      Description="Allow all signed packaged apps by default"
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
        $ruleId = [System.Guid]::NewGuid().ToString()
        Write-Host "  Generated UUID $ruleId --> $productName" -ForegroundColor DarkCyan
        Write-Log "Generated Deny rule UUID: $ruleId  |  App: $productName" "INFO"

        $rulesXml += @"

    <!-- Deny $productName -->
    <FilePublisherRule Id="$ruleId"
      Name="Block $productName"
      Description="Block $productName for all users"
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

    $fullPolicy = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
$rulesXml
  </RuleCollection>
</AppLockerPolicy>
"@

    $policyPath = "C:\AppLockerPolicy.xml"

    try {
        $fullPolicy | Out-File $policyPath -Encoding UTF8
        Write-Host "`nPolicy saved to $policyPath" -ForegroundColor Cyan
        Write-Log "AppLocker policy XML saved to: $policyPath" "SUCCESS"
    }
    catch {
        Write-Log "Failed to save AppLocker policy XML to '$policyPath'. Error: $($_.Exception.Message)" "ERROR"
    }

    try {
        Set-AppLockerPolicy -XmlPolicy $policyPath -Merge
        Write-Host "AppLocker policy applied!" -ForegroundColor Green
        Write-Log "AppLocker policy applied successfully (merged)." "SUCCESS"
    }
    catch {
        Write-Host "Failed to apply AppLocker policy!" -ForegroundColor Red
        Write-Log "Failed to apply AppLocker policy. Error: $($_.Exception.Message)" "ERROR"
    }

    try {
        $scConfigResult = sc.exe config AppIDSvc start= auto 2>&1
        $scStartResult  = sc.exe start  AppIDSvc        2>&1

        Write-Host "AppIDSvc service started!" -ForegroundColor Green
        Write-Log "AppIDSvc configured to Auto-start. Config output: $scConfigResult" "SUCCESS"
        Write-Log "AppIDSvc start output: $scStartResult" "INFO"
    }
    catch {
        Write-Host "Warning: Could not start AppIDSvc." -ForegroundColor Yellow
        Write-Log "Warning: Failed to configure/start AppIDSvc. Error: $($_.Exception.Message)" "WARNING"
    }
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "             BLOCK SUMMARY              " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Log "--- Block Summary ---" "INFO"

if ($blockedExe.Count -gt 0) {
    Write-Host "`nEXE Apps Blocked (Registry):" -ForegroundColor Yellow
    $blockedExe | ForEach-Object {
        Write-Host "  - $_.exe" -ForegroundColor Red
        Write-Log "EXE blocked: $_.exe" "SUCCESS"
    }
}

if ($foundApps.Count -gt 0) {
    Write-Host "`nStore Apps Blocked (AppLocker):" -ForegroundColor Yellow
    $foundApps | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
        Write-Log "Store app blocked: $_" "SUCCESS"
    }
}

if ($blockedExe.Count -eq 0 -and $foundApps.Count -eq 0) {
    Write-Host "`nNo apps were blocked." -ForegroundColor Yellow
    Write-Log "No apps were blocked. Check input names and try again." "WARNING"
}

Write-Host "`n---- Completed Blocking Applications ----`n" -ForegroundColor Green
Write-Log "Script completed. EXE blocked: $($blockedExe.Count) | Store blocked: $($foundApps.Count)" "SUCCESS"
Write-Log "Full log saved to: $LogFile" "INFO"
Add-Content -Path $LogFile -Value "========================================"
