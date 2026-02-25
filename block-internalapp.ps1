# Run as Administrator

# Step 1: Define apps to block (search keywords)
$appsToBlock = @("MSTeams", "XboxApp", "Microsoft.OutlookForWindows", "Microsoft.WindowsNotepad")

# Step 2: Find installed apps and extract ProductName (exact match first, fallback to like)
Write-Host "`nSearching for apps..." -ForegroundColor Cyan
$foundApps = @()

foreach ($app in $appsToBlock) {
    # Try exact match first
    $pkg = Get-AppxPackage | Where-Object { $_.Name -eq $app } | Select-Object -First 1

    # Fallback to partial match if not found
    if (-not $pkg) {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like "*$app*" } | Select-Object -First 1
    }

    if ($pkg) {
        Write-Host "Found: $($pkg.Name)" -ForegroundColor Green
        $foundApps += $pkg.Name
    } else {
        Write-Host "Not Found: $app (skipping)" -ForegroundColor Yellow
    }
}

if ($foundApps.Count -eq 0) {
    Write-Host "No apps found. Exiting." -ForegroundColor Red
    exit
}

# Step 3: Build XML rules
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

# Deny rules for each found app
foreach ($productName in $foundApps) {
    $ruleId = [System.Guid]::NewGuid().ToString()
    Write-Host "  Generated UUID $ruleId for --> $productName" -ForegroundColor DarkCyan

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

# Step 4: Wrap in full policy XML
$fullPolicy = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
$rulesXml
  </RuleCollection>
</AppLockerPolicy>
"@

# Step 5: Save to file
$policyPath = "C:\AppLockerPolicy.xml"
$fullPolicy | Out-File $policyPath -Encoding UTF8
Write-Host "`nPolicy saved to $policyPath" -ForegroundColor Cyan

# Step 6: Apply the policy
Set-AppLockerPolicy -XmlPolicy $policyPath -Merge
Write-Host "AppLocker policy applied!" -ForegroundColor Green

# Step 7: Start AppIDSvc using sc.exe (avoids access denied on Set-Service)
sc.exe config AppIDSvc start= auto | Out-Null
sc.exe start AppIDSvc | Out-Null
Write-Host "AppIDSvc service started!" -ForegroundColor Green

Write-Host "`nDone! The following apps are now blocked:" -ForegroundColor Yellow
$foundApps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }