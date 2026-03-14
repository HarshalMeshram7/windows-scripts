# --------------------------------------------------------------
# unblockallapps.ps1
# Run as Administrator
# Usage: .\unblockallapps.ps1              # Unblocks ALL
#        .\unblockallapps.ps1 outlook      # Targeted
#        .\unblockallapps.ps1 outlook chrome
# --------------------------------------------------------------

#Requires -RunAsAdministrator

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$TargetApps
)

$ErrorActionPreference = "SilentlyContinue"

$filterMode = $TargetApps -and $TargetApps.Count -gt 0
$normalizedTargets = @()
foreach ($arg in $TargetApps) {
    $arg -split '[,\s]+' | ForEach-Object {
        $clean = $_.Trim().ToLower() -replace '\.exe$', ''
        if ($clean -ne '') { $normalizedTargets += $clean }
    }
}

$unblockedExe   = @()
$unblockedStore = @()

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "     Scanning System For Blocked Apps    " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

if ($filterMode) {
    Write-Host "Filter mode ON. Targeting: $($normalizedTargets -join ', ')`n" -ForegroundColor Cyan
} else {
    Write-Host "No filter - unblocking ALL apps.`n" -ForegroundColor Cyan
}

# ============================================================
# PRE-STEP: Remove restrictive policies
# ============================================================

Write-Host "Removing restrictive policies..." -ForegroundColor Cyan

$policy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx"
if (Test-Path $policy) {
    Remove-ItemProperty -Path $policy -Name "AllowAllTrustedApps" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $policy -Name "BlockNonAdminUserInstall" -ErrorAction SilentlyContinue
    if ((Get-Item $policy).Property.Count -eq 0) { Remove-Item $policy -Force }
    Write-Host "  AppX policies removed." -ForegroundColor Green
}

$programsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs"
if (Test-Path $programsPath) {
    Remove-ItemProperty -Path $programsPath -Name "NoProgramsAndFeatures" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $programsPath -Name "NoAddRemovePrograms" -ErrorAction SilentlyContinue
    Write-Host "  Programs and Features policies removed." -ForegroundColor Green
}

$explorerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (Test-Path $explorerPath) {
    Remove-ItemProperty -Path $explorerPath -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue
    Write-Host "  Explorer policies removed." -ForegroundColor Green
}

# ============================================================
# PART 1: Unblock EXE Apps (Registry Debugger Method)
# ============================================================

Write-Host "`nChecking EXE blocks in registry..." -ForegroundColor Cyan

$baseRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

Get-ChildItem $baseRegPath | ForEach-Object {

    $exeName = $_.PSChildName
    $regPath = "$baseRegPath\$exeName"

    if ($filterMode) {
        $normalizedExeName = $exeName.ToLower() -replace '\.exe$', ''
        if ($normalizedTargets -notcontains $normalizedExeName) { return }
    }

    $debugger = Get-ItemProperty -Path $regPath -Name "Debugger" -ErrorAction SilentlyContinue

    if ($debugger) {
        Write-Host "  BLOCK FOUND: $exeName" -ForegroundColor Red
        Remove-ItemProperty -Path $regPath -Name "Debugger" -Force
        Write-Host "  UNBLOCKED (EXE): $exeName" -ForegroundColor Green
        $remaining = Get-Item -Path $regPath | Select-Object -ExpandProperty Property
        if ($remaining.Count -eq 0) { Remove-Item -Path $regPath -Force }
        $unblockedExe += $exeName
    }
}

if ($unblockedExe.Count -eq 0) {
    Write-Host "  No EXE apps were blocked." -ForegroundColor Yellow
}

# ============================================================
# PART 2: Remove AppLocker Deny Rules + Disable Enforcement
# ============================================================

Write-Host "`nChecking AppLocker rules..." -ForegroundColor Cyan

$currentPolicyXml = Get-AppLockerPolicy -Effective -Xml
[xml]$policyDoc = $currentPolicyXml

foreach ($collection in $policyDoc.AppLockerPolicy.RuleCollection) {

    $denyRules = $collection.FilePublisherRule | Where-Object { $_.Action -eq "Deny" }

    foreach ($rule in $denyRules) {

        if ($filterMode) {
            $ruleNameLower = $rule.Name.ToLower()
            $matched = $normalizedTargets | Where-Object { $ruleNameLower -like "*$_*" }
            if (-not $matched) { continue }
        }

        Write-Host "  Removing rule: $($rule.Name)" -ForegroundColor Red
        $collection.RemoveChild($rule) | Out-Null
        $unblockedStore += $rule.Name
    }

    $collection.EnforcementMode = "NotConfigured"
    Write-Host "  EnforcementMode -> NotConfigured: $($collection.Type)" -ForegroundColor Green
}

$cleanedPolicyPath = "C:\AppLockerPolicy_Cleaned.xml"
$policyDoc.Save($cleanedPolicyPath)
Set-AppLockerPolicy -XmlPolicy $cleanedPolicyPath
Write-Host "  AppLocker policy applied." -ForegroundColor Green

# ============================================================
# PART 3: Clear SrpV2 + AppCache + Runtime Cache
# ============================================================

Write-Host "`nClearing AppLocker runtime cache..." -ForegroundColor Cyan

$srpV2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2"
if (Test-Path $srpV2) {
    Remove-Item -Path $srpV2 -Recurse -Force
    Write-Host "  SrpV2 registry key deleted." -ForegroundColor Green
} else {
    Write-Host "  SrpV2 already gone." -ForegroundColor Yellow
}

# Stop AppIDSvc first so cache files are not locked
Stop-Service AppIDSvc -Force
Write-Host "  AppIDSvc stopped." -ForegroundColor Green

# Delete AppCache.dat while service is stopped
Remove-Item "C:\Windows\System32\AppLocker\AppCache.dat" -Force -ErrorAction SilentlyContinue
Write-Host "  AppCache.dat deleted." -ForegroundColor Green

# Clear Srp\Gp runtime cache values
$srpGp = "HKLM:\SYSTEM\CurrentControlSet\Control\Srp\Gp"
if (Test-Path $srpGp) {
    Remove-ItemProperty -Path $srpGp -Name "RuleCount" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $srpGp -Name "LastWriteTime" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $srpGp -Name "LastSmartlockerEnabled" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $srpGp -Name "LastGpNotifyTime" -ErrorAction SilentlyContinue
    Write-Host "  Srp\Gp runtime cache cleared." -ForegroundColor Green
}

# Leave AppIDSvc stopped - Windows will restart it on demand
# This avoids the delay caused by restarting and reloading policy
Write-Host "  AppIDSvc left stopped - will restart on demand." -ForegroundColor Green

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