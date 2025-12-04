<#
UNDO install/uninstall restrictions for child accounts
Skips Administrator and ParentAdmin
#>

Write-Host "Removing restrictions from child accounts..."

$ExcludedUsers = @("Administrator", "ParentAdmin")

$profiles = Get-CimInstance Win32_UserProfile | Where-Object {
    $_.LocalPath -like "C:\Users\*" -and $_.Loaded -eq $false
}

foreach ($profile in $profiles) {

    $userPath = $profile.LocalPath
    $userName = Split-Path $userPath -Leaf

    if ($ExcludedUsers -contains $userName) {
        Write-Host "Skipping admin: $userName"
        continue
    }

    $hive = "$userPath\NTUSER.DAT"
    if (-not (Test-Path $hive)) { continue }

    Write-Host "Restoring permissions for: $userName"

    reg load HKU\CHILD_$userName "$hive" >$null 2>&1

    reg delete "HKU\CHILD_$userName\Software\Microsoft\Windows\CurrentVersion\Policies\Programs" /f
    reg delete "HKU\CHILD_$userName\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /f
    reg delete "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\Explorer" /f
    reg delete "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\Safer" /f
    reg delete "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\PowerShell" /f
    reg delete "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\AppInstaller" /f

    reg unload HKU\CHILD_$userName >$null 2>&1
}

Write-Output '{"status":"success","child_install_uninstall_restored":1}'
