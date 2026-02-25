# Run as Administrator

# Step 1: Define apps to unblock
$appsToUnblock = @("MSTeams", "XboxApp", "Microsoft.OutlookForWindows", "Microsoft.WindowsNotepad")

Write-Host "`nFetching current AppLocker policy..." -ForegroundColor Cyan

# Step 2: Get current policy XML
$currentPolicyXml = Get-AppLockerPolicy -Effective -Xml
[xml]$policyDoc = $currentPolicyXml

# Step 3: Remove ALL Deny rules for our apps
$removedApps = @()

foreach ($app in $appsToUnblock) {
    $pkg = Get-AppxPackage | Where-Object { $_.Name -eq $app } | Select-Object -First 1
    if (-not $pkg) {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like "*$app*" } | Select-Object -First 1
    }

    $productName = if ($pkg) { $pkg.Name } else { $app }

    $rules = $policyDoc.AppLockerPolicy.RuleCollection | Where-Object { $_.Type -eq "Appx" }

    foreach ($ruleCollection in $rules) {
        $matchingRules = $ruleCollection.FilePublisherRule | Where-Object {
            $_.Action -eq "Deny" -and $_.Name -like "*$productName*"
        }

        foreach ($rule in $matchingRules) {
            Write-Host "Removing: $($rule.Name)" -ForegroundColor Red
            $ruleCollection.RemoveChild($rule) | Out-Null
            $removedApps += $productName
        }
    }
}

# Step 4: Save cleaned XML
$cleanedPolicyPath = "C:\AppLockerPolicy_Cleaned.xml"
$policyDoc.Save($cleanedPolicyPath)
Write-Host "`nCleaned policy saved to $cleanedPolicyPath" -ForegroundColor Cyan

# Step 5: FULLY REPLACE policy (not merge) using secedit workaround
# First set to NotConfigured to wipe existing
$resetPolicy = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Exe" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Script" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Msi" EnforcementMode="NotConfigured" />
  <RuleCollection Type="Dll" EnforcementMode="NotConfigured" />
</AppLockerPolicy>
"@

$resetPolicyPath = "C:\AppLockerPolicy_Reset.xml"
$resetPolicy | Out-File $resetPolicyPath -Encoding UTF8

# Wipe current policy
Set-AppLockerPolicy -XmlPolicy $resetPolicyPath
Write-Host "Existing policy wiped..." -ForegroundColor Yellow

# Re-apply cleaned policy
Set-AppLockerPolicy -XmlPolicy $cleanedPolicyPath
Write-Host "Cleaned policy re-applied!" -ForegroundColor Green

# Step 6: Restart AppIDSvc to force refresh
sc.exe stop AppIDSvc | Out-Null
Start-Sleep -Seconds 2
sc.exe start AppIDSvc | Out-Null
Write-Host "AppIDSvc restarted!" -ForegroundColor Green

if ($removedApps.Count -gt 0) {
    Write-Host "`nDone! The following apps are now unblocked:" -ForegroundColor Yellow
    $removedApps | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
} else {
    Write-Host "`nNo matching Deny rules found. Policy has been reset." -ForegroundColor Yellow
}