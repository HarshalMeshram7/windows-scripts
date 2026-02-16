# ==========================================
# WINDOWS DIY MDM / SCALEFUSION-LIKE LOCKDOWN
# Install + Uninstall Block (ALL-IN-ONE)
# ==========================================

Write-Host "Starting full Windows lockdown..." -ForegroundColor Cyan

# --- ADMIN CHECK ---
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Error "Run this script as Administrator."
    exit 1
}

# ------------------------------------------------
# 1. ENABLE APPLICATION IDENTITY (AppLocker core)
# ------------------------------------------------
Write-Host "Enabling Application Identity service..."
sc.exe config AppIDSvc start= auto | Out-Null
sc.exe start AppIDSvc | Out-Null

# ------------------------------------------------
# 2. APPLOCKER – DEFAULT ALLOW + ENFORCE
# ------------------------------------------------
Write-Host "Applying AppLocker default policy..."
$apXml = "$env:TEMP\AppLocker_Default.xml"
Get-AppLockerPolicy -Default -Local | Out-File $apXml -Encoding utf8
Set-AppLockerPolicy -XmlPolicy $apXml -Merge

# Enforce AppLocker
reg add "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Exe" /v EnforcementMode /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Msi" /v EnforcementMode /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Script" /v EnforcementMode /t REG_DWORD /d 1 /f

# ------------------------------------------------
# 3. BLOCK UNINSTALL EXECUTABLES (AppLocker deny)
# ------------------------------------------------
Write-Host "Blocking uninstall executables..."

$denyUninstallXml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="{A1A1A1A1-A1A1-A1A1-A1A1-A1A1A1A1A1A1}"
      Name="Deny Uninstallers"
      Description="Blocks uninstall.exe and setup uninstallers"
      UserOrGroupSid="S-1-1-0"
      Action="Deny">
      <Conditions>
        <FilePathCondition Path="*\uninstall*.exe" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@

$denyPath = "$env:TEMP\AppLocker_BlockUninstall.xml"
$denyUninstallXml | Out-File $denyPath -Encoding utf8
Set-AppLockerPolicy -XmlPolicy $denyPath -Merge

# ------------------------------------------------
# 4. SOFTWARE RESTRICTION POLICY (DENY BY DEFAULT)
# ------------------------------------------------
Write-Host "Applying Software Restriction Policy..."

reg add "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" /v DefaultLevel /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers" /v TransparentEnabled /t REG_DWORD /d 1 /f

# Allow OS + Program Files
reg add "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths\{WIN}" /v ItemData /t REG_SZ /d "C:\Windows\*" /f
reg add "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths\{PF}" /v ItemData /t REG_SZ /d "C:\Program Files\*" /f
reg add "HKLM\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths\{PF86}" /v ItemData /t REG_SZ /d "C:\Program Files (x86)\*" /f

# ------------------------------------------------
# 5. BLOCK WINDOWS INSTALLER (MSI INSTALL + UNINSTALL)
# ------------------------------------------------
Write-Host "Disabling Windows Installer..."
reg add "HKLM\Software\Policies\Microsoft\Windows\Installer" /v DisableMSI /t REG_DWORD /d 2 /f

# ------------------------------------------------
# 6. REMOVE ALL UNINSTALL UI
# ------------------------------------------------
Write-Host "Removing uninstall UI..."

# Apps & Features / Control Panel
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Uninstall" /v NoAddRemovePrograms /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoControlPanel /t REG_DWORD /d 1 /f

# ------------------------------------------------
# 7. BLOCK ADVANCED UNINSTALL METHODS
# ------------------------------------------------
Write-Host "Blocking advanced uninstall tools..."

# CMD
reg add "HKCU\Software\Policies\Microsoft\Windows\System" /v DisableCMD /t REG_DWORD /d 1 /f

# Task Manager
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /t REG_DWORD /d 1 /f

# PowerShell scripts
reg add "HKLM\Software\Policies\Microsoft\Windows\PowerShell" /v EnableScripts /t REG_DWORD /d 0 /f

# ------------------------------------------------
# 8. APPLY POLICIES
# ------------------------------------------------
Write-Host "Applying policies and refreshing..."
gpupdate /force

Write-Host "LOCKDOWN COMPLETE REBOOT REQUIRED" -ForegroundColor Green
