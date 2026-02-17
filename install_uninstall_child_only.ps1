# =====================================================
# WINDOWS DIY MDM / SCALEFUSION-LIKE LOCKDOWN
# STANDARD USERS ONLY (ADMINS EXCLUDED)
# INSTALL + UNINSTALL BLOCK
# =====================================================

Write-Host "Starting Windows lockdown for STANDARD USERS ONLY..." -ForegroundColor Cyan

# -----------------------------------------------------
# ADMIN CHECK
# -----------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) {
    Write-Error "Run this script as Administrator."
    exit 1
}

# -----------------------------------------------------
# 1. ENABLE APPLICATION IDENTITY (AppLocker Core)
# -----------------------------------------------------
Write-Host "Enabling Application Identity service..."
sc.exe config AppIDSvc start= auto | Out-Null
sc.exe start AppIDSvc | Out-Null

# -----------------------------------------------------
# 2. ENFORCE APPLOCKER (SYSTEM LEVEL)
# -----------------------------------------------------
Write-Host "Enforcing AppLocker..."
reg add "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Exe" /v EnforcementMode /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Msi" /v EnforcementMode /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\SrpV2\Script" /v EnforcementMode /t REG_DWORD /d 1 /f

# -----------------------------------------------------
# 3. APPLOCKER RULES (VALID XML, USERS ONLY)
# -----------------------------------------------------
Write-Host "Applying AppLocker rules for standard users..."

$adminGuid = ([guid]::NewGuid().ToString().ToUpper())
$userGuid  = ([guid]::NewGuid().ToString().ToUpper())

$applockerXml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">

    <FilePathRule
      Id="$adminGuid"
      Name="Allow All for Administrators"
      Description="Full access for local administrators"
      UserOrGroupSid="S-1-5-32-544"
      Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>

    <FilePathRule
      Id="$userGuid"
      Name="Deny Uninstallers for Standard Users"
      Description="Blocks uninstall and setup executables"
      UserOrGroupSid="S-1-5-32-545"
      Action="Deny">
      <Conditions>
        <FilePathCondition Path="*\uninstall*.exe" />
      </Conditions>
    </FilePathRule>

  </RuleCollection>
</AppLockerPolicy>
"@

$xmlPath = "$env:TEMP\AppLocker_UsersOnly.xml"
$applockerXml | Out-File $xmlPath -Encoding utf8
Set-AppLockerPolicy -XmlPolicy $xmlPath -Merge

# -----------------------------------------------------
# 4. BLOCK WINDOWS INSTALLER (STANDARD USERS ONLY)
# -----------------------------------------------------
Write-Host "Blocking Windows Installer for standard users..."
reg add "HKCU\Software\Policies\Microsoft\Windows\Installer" `
    /v DisableMSI /t REG_DWORD /d 2 /f

# -----------------------------------------------------
# 5. REMOVE UNINSTALL UI (STANDARD USERS ONLY)
# -----------------------------------------------------
Write-Host "Removing uninstall UI for standard users..."

# Hide Apps & Features
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Uninstall" `
    /v NoAddRemovePrograms /t REG_DWORD /d 1 /f

# Hide Control Panel
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    /v NoControlPanel /t REG_DWORD /d 1 /f

# -----------------------------------------------------
# 6. BLOCK ADVANCED UNINSTALL METHODS (USERS ONLY)
# -----------------------------------------------------
Write-Host "Blocking advanced uninstall tools..."

# Disable Command Prompt
reg add "HKCU\Software\Policies\Microsoft\Windows\System" `
    /v DisableCMD /t REG_DWORD /d 1 /f

# Disable Task Manager
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    /v DisableTaskMgr /t REG_DWORD /d 1 /f

# -----------------------------------------------------
# 7. APPLY POLICIES
# -----------------------------------------------------
Write-Host "Applying policies..."
gpupdate /force

Write-Host "LOCKDOWN COMPLETE REBOOT REQUIRED" -ForegroundColor Green
