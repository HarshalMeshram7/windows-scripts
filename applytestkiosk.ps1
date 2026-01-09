# ================================
# MULTI-APP KIOSK ENABLE SCRIPT
# Windows 10 / 11
# ================================

$KioskUser = "KioskUser"
$KioskPassword = "1234"
$KioskDir = "C:\Kiosk"
$KioskXmlPath = "$KioskDir\kiosk.xml"

Write-Host "=== Creating Kiosk User ==="

if (-not (Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue)) {
    net user $KioskUser $KioskPassword /add
    net localgroup Users $KioskUser /add
}

net localgroup Administrators $KioskUser /delete 2>$null

New-Item -ItemType Directory -Path $KioskDir -Force | Out-Null

Write-Host "=== Creating Assigned Access XML ==="

$KioskXml = @"
<?xml version="1.0" encoding="utf-8"?>
<AssignedAccessConfiguration
  xmlns="http://schemas.microsoft.com/AssignedAccess/2017/config">

  <Profiles>
    <Profile Id="{EDU-MULTI-KIOSK}">
      <AllAppsList>
        <AllowedApps>
          <App AppUserModelId="Microsoft.MicrosoftEdge_8wekyb3d8bbwe!MicrosoftEdge"/>
          <App DesktopAppPath="C:\Windows\System32\notepad.exe"/>
          <App DesktopAppPath="C:\Windows\System32\calc.exe"/>
        </AllowedApps>
      </AllAppsList>
    </Profile>
  </Profiles>

  <Configs>
    <Config>
      <Account>$KioskUser</Account>
      <ProfileId>{EDU-MULTI-KIOSK}</ProfileId>
    </Config>
  </Configs>
</AssignedAccessConfiguration>
"@

$KioskXml | Out-File -Encoding utf8 -FilePath $KioskXmlPath

Write-Host "=== Applying Assigned Access ==="

Set-AssignedAccess -ConfigurationFilePath $KioskXmlPath

Write-Host "=== Kiosk Applied Successfully ==="
Write-Host "Rebooting system..."

#shutdown /r /t 0
