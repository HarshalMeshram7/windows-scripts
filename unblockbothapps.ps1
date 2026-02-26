# Run as Administrator
# Usage: .\unblock-apps.ps1 chrome, postman, Teams, Xbox, Outlook, Notepad

param (
    [Parameter(Mandatory = $true)]
    [string[]]$AppNames
)

# Clean up app names
$AppNames = $AppNames | ForEach-Object { $_.Trim().Trim(',') } | Where-Object { $_ -ne "" }

$unblockedExe   = @()
$unblockedStore = @()

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "        Auto-Detecting App Types        " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

$exeApps   = @()
$storeApps = @()

foreach ($app in $AppNames) {

    # Check if it's a Store/UWP app first
    $pkg = Get-AppxPackage | Where-Object { $_.Name -eq $app } | Select-Object -First 1
    if (-not $pkg) {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like "*$app*" } | Select-Object -First 1
    }

    if ($pkg) {
        Write-Host "  [STORE]  Detected: $($pkg.Name)" -ForegroundColor Cyan
        $storeApps += $pkg.Name
    } else {
        Write-Host "  [EXE]    Detected: $app" -ForegroundColor DarkYellow
        $exeApps += $app
    }
}

# ============================================================
# PART 1: Unblock EXE Apps (Remove Registry Debugger Key)
# ============================================================

if ($exeApps.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Unblocking EXE Apps via Registry...  " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta

    foreach ($app in $exeApps) {
        $cleanName = $app -replace '\.exe$', ''
        $exeName   = "$cleanName.exe"
        $RegPath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

        if (Test-Path $RegPath) {
            # Check if Debugger property exists
            $debugger = Get-ItemProperty -Path $RegPath -Name "Debugger" -ErrorAction SilentlyContinue

            if ($debugger) {
                Remove-ItemProperty -Path $RegPath -Name "Debugger" -Force
                Write-Host "  UNBLOCKED (EXE): $exeName" -ForegroundColor Green

                # Remove the key entirely if it's now empty
                $remaining = Get-Item -Path $RegPath | Select-Object -ExpandProperty Property
                if ($remaining.Count -eq 0) {
                    Remove-Item -Path $RegPath -Force
                }

                $unblockedExe += $exeName
            } else {
                Write-Host "  NOT BLOCKED: $exeName (no block rule found)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  NOT FOUND: $exeName (registry key doesn't exist)" -ForegroundColor Yellow
        }
    }
}

# ============================================================
# PART 2: Unblock Store Apps (Remove AppLocker Deny Rules)
# ============================================================

if ($storeApps.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host " Unblocking Store Apps via AppLocker... " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta

    Write-Host "`nFetching current AppLocker policy..." -ForegroundColor Cyan
    $currentPolicyXml = Get-AppLockerPolicy -Effective -Xml
    [xml]$policyDoc = $currentPolicyXml

    foreach ($productName in $storeApps) {
        $ruleCollections = $policyDoc.AppLockerPolicy.RuleCollection | Where-Object { $_.Type -eq "Appx" }

        foreach ($ruleCollection in $ruleCollections) {
            $matchingRules = $ruleCollection.FilePublisherRule | Where-Object {
                $_.Action -eq "Deny" -and $_.Name -like "*$productName*"
            }

            if ($matchingRules) {
                foreach ($rule in $matchingRules) {
                    Write-Host "  Removing rule: $($rule.Name)" -ForegroundColor Red
                    $ruleCollection.RemoveChild($rule) | Out-Null
                }
                $unblockedStore += $productName
                Write-Host "  UNBLOCKED (STORE): $productName" -ForegroundColor Green
            } else {
                Write-Host "  NOT BLOCKED: $productName (no deny rule found)" -ForegroundColor Yellow
            }
        }
    }

    # Save cleaned policy
    $cleanedPolicyPath = "C:\AppLockerPolicy_Cleaned.xml"
    $policyDoc.Save($cleanedPolicyPath)
    Write-Host "`nCleaned policy saved to $cleanedPolicyPath" -ForegroundColor Cyan

    # Wipe current policy first
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
    Set-AppLockerPolicy -XmlPolicy $resetPolicyPath
    Write-Host "Existing policy wiped..." -ForegroundColor Yellow

    # Re-apply cleaned policy
    Set-AppLockerPolicy -XmlPolicy $cleanedPolicyPath
    Write-Host "Cleaned policy re-applied!" -ForegroundColor Green

    # Restart AppIDSvc to force refresh
    sc.exe stop AppIDSvc | Out-Null
    Start-Sleep -Seconds 2
    sc.exe start AppIDSvc | Out-Null
    Write-Host "AppIDSvc restarted!" -ForegroundColor Green
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "            UNBLOCK SUMMARY             " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($unblockedExe.Count -gt 0) {
    Write-Host "`nEXE Apps Unblocked (Registry):" -ForegroundColor Yellow
    $unblockedExe | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
}

if ($unblockedStore.Count -gt 0) {
    Write-Host "`nStore Apps Unblocked (AppLocker):" -ForegroundColor Yellow
    $unblockedStore | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
}

if ($unblockedExe.Count -eq 0 -and $unblockedStore.Count -eq 0) {
    Write-Host "`nNo apps were unblocked." -ForegroundColor Yellow
}

Write-Host "`n---- Completed Unblocking Applications ----`n" -ForegroundColor Green