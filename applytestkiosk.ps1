# ==========================================
# Create Kiosk User (if not exists)
# + Enable Multi-App Kiosk Mode (CSP)
# ==========================================

$KioskUser = "KioskUser"
$KioskPassword = "P@ssw0rd@123"   # Change before production

# -------------------------------
# Create Kiosk User if missing
# -------------------------------
if (-not (Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue)) {

    $SecurePassword = ConvertTo-SecureString $KioskPassword -AsPlainText -Force

    New-LocalUser `
        -Name $KioskUser `
        -Password $SecurePassword `
        -FullName "Kiosk User" `
        -Description "Local kiosk account" `
        -PasswordNeverExpires `
        -UserMayNotChangePassword

    Add-LocalGroupMember -Group "Users" -Member $KioskUser

    Write-Output "✅ Kiosk user created successfully."
}
else {
    Write-Output "ℹ️ Kiosk user already exists."
}

# -------------------------------
# Assigned Access CSP XML
# -------------------------------
$KioskXML = @"
<?xml version="1.0" encoding="utf-8"?>
<AssignedAccessConfiguration
    xmlns="http://schemas.microsoft.com/AssignedAccess/2017/config"
    xmlns:rs5="http://schemas.microsoft.com/AssignedAccess/201810/config">

  <Profiles>
    <Profile Id="{D8B2F45E-9A0E-4E25-9C0A-111111111111}">
      <AllAppsList>
        <AllowedApps>

          <!-- Microsoft Edge -->
          <App DesktopAppPath="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"/>

          <!-- File Explorer -->
          <App DesktopAppPath="C:\Windows\explorer.exe"/>

          <!-- Notepad -->
          <App DesktopAppPath="C:\Windows\System32\notepad.exe"/>

          <!-- Calculator -->
          <App AppUserModelId="Microsoft.WindowsCalculator_8wekyb3d8bbwe!App"/>

        </AllowedApps>
      </AllAppsList>

      <!-- Taskbar -->
      <rs5:Taskbar ShowTaskbar="true"/>

    </Profile>
  </Profiles>

  <Configs>
    <Config>
      <Account>$KioskUser</Account>
      <DefaultProfile Id="{D8B2F45E-9A0E-4E25-9C0A-111111111111}"/>
    </Config>
  </Configs>

</AssignedAccessConfiguration>
"@

# -------------------------------
# Apply CSP (Base64)
# -------------------------------
$EncodedXML = [Convert]::ToBase64String(
    [System.Text.Encoding]::Unicode.GetBytes($KioskXML)
)

$CSPPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\AssignedAccess"
New-Item -Path $CSPPath -Force | Out-Null

Set-ItemProperty `
    -Path $CSPPath `
    -Name "Configuration" `
    -Value $EncodedXML `
    -Type String

Write-Output "✅ Multi-App Kiosk Mode configured. Restart required."
shutdown /r /t 10
