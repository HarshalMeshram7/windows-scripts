<#
CHILD INSTALL + UNINSTALL RESTRICTIONS
Applies to all NON-admin accounts
Skips Administrator and ParentAdmin
#>

Write-Host "Applying install + uninstall restrictions to child accounts..."

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

    Write-Host "Applying restrictions to: $userName"

    # Load child HKCU hive
    reg load HKU\CHILD_$userName "$hive" >$null 2>&1

    # ------------------------------
    # BLOCK UNINSTALL
    # ------------------------------

    reg add "HKU\CHILD_$userName\Software\Microsoft\Windows\CurrentVersion\Policies\Programs" /v NoProgramsUninstall /t REG_DWORD /d 1 /f
    reg add "HKU\CHILD_$userName\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoPrograms /t REG_DWORD /d 1 /f
    reg add "HKU\CHILD_$userName\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoUninstallFromStart /t REG_DWORD /d 1 /f
    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\Explorer" /v NoUninstallAppPage /t REG_DWORD /d 1 /f

    # ------------------------------
    # BLOCK INSTALL (EXE, MSI, PS1 etc.)
    # ------------------------------

    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" /v DefaultLevel /t REG_DWORD /d 0 /f
    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" /v TransparentEnabled /t REG_DWORD /d 1 /f
    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" /v ExecutableTypes /t REG_SZ /d ".exe;.msi;.cmd;.bat;.ps1;.vbs;.com;.msp" /f

    # Block PowerShell Installer Scripts
    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\PowerShell" /v EnableScripts /t REG_DWORD /d 0 /f

    # Block Winget / Microsoft Store installs
    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\AppInstaller" /v EnableAppInstaller /t REG_DWORD /d 0 /f
    reg add "HKU\CHILD_$userName\Software\Policies\Microsoft\Windows\AppInstaller" /v EnableMSStoreSource /t REG_DWORD /d 0 /f

    # Unload child hive
    reg unload HKU\CHILD_$userName >$null 2>&1
}

Write-Output '{"status":"success","child_install_uninstall_blocked":1}'
