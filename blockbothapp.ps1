# Run as Administrator
# Usage: .\block-apps.ps1 chrome, postman, Teams, Xbox, Outlook, Notepad

param (
    [Parameter(Mandatory = $true)]
    [string[]]$AppNames
)

# Clean up app names (remove spaces and commas)
$AppNames = $AppNames | ForEach-Object { $_.Trim().Trim(',') } | Where-Object { $_ -ne "" }

$blockedExe   = @()
$blockedStore = @()
$foundApps    = @()

$DebuggerPath = 'mshta.exe "javascript:alert(''This application has been blocked by your administrator.'');close();"'

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "        Auto-Detecting App Types        " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

foreach ($app in $AppNames) {

    # ---- Check if it's a Store/UWP app first ----
    $pkg = Get-AppxPackage | Where-Object { $_.Name -eq $app } | Select-Object -First 1
    if (-not $pkg) {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like "*$app*" } | Select-Object -First 1
    }

    if ($pkg) {
        # It's a Store app
        Write-Host "  [STORE]  Detected: $($pkg.Name)" -ForegroundColor Cyan
        $foundApps += $pkg.Name
        $blockedStore += $app
    } else {
        # Treat as EXE app
        Write-Host "  [EXE]    Detected: $app" -ForegroundColor DarkYellow
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

    foreach ($app in $blockedExe) {
        $cleanName = $app -replace '\.exe$', ''
        $exeName   = "$cleanName.exe"
        $RegPath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

        New-Item -Path $RegPath -Force | Out-Null
        New-ItemProperty `
            -Path $RegPath `
            -Name "Debugger" `
            -PropertyType String `
            -Value $DebuggerPath `
            -Force | Out-Null

        Write-Host "  BLOCKED (EXE): $exeName" -ForegroundColor Red
    }
}

# ============================================================
# PART 2: Block Store Apps via AppLocker
# ============================================================

if ($foundApps.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Blocking Store Apps via AppLocker...  " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta

    Write-Host "`nGenerating AppLocker rules..." -ForegroundColor Cyan

    # Allow All rule (required)
    $allowRuleId = [System.Guid]::NewGuid().ToString()
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
    $fullPolicy | Out-File $policyPath -Encoding UTF8
    Write-Host "`nPolicy saved to $policyPath" -ForegroundColor Cyan

    Set-AppLockerPolicy -XmlPolicy $policyPath -Merge
    Write-Host "AppLocker policy applied!" -ForegroundColor Green

    sc.exe config AppIDSvc start= auto | Out-Null
    sc.exe start AppIDSvc | Out-Null
    Write-Host "AppIDSvc service started!" -ForegroundColor Green
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "             BLOCK SUMMARY              " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($blockedExe.Count -gt 0) {
    Write-Host "`nEXE Apps Blocked (Registry):" -ForegroundColor Yellow
    $blockedExe | ForEach-Object { Write-Host "  - $_.exe" -ForegroundColor Red }
}

if ($foundApps.Count -gt 0) {
    Write-Host "`nStore Apps Blocked (AppLocker):" -ForegroundColor Yellow
    $foundApps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

if ($blockedExe.Count -eq 0 -and $foundApps.Count -eq 0) {
    Write-Host "`nNo apps were blocked." -ForegroundColor Yellow
}

Write-Host "`n---- Completed Blocking Applications ----`n" -ForegroundColor Green