# PowerShell script to restrict standard users from installing or uninstalling software
# This works on Windows 10/11 Pro, Enterprise, or Education editions (requires Group Policy access)
# Run this script as Administrator

# Note: This primarily hides the "Programs and Features" page (appwiz.cpl) in Control Panel
# and the Installed apps page in Settings for standard users.
# It does not fully prevent per-user installations (e.g., portable apps or Microsoft Store apps).
# For stronger restrictions, consider AppLocker (Pro+ editions) or third-party tools.

# 1. Hide "Programs and Features" in Control Panel
$regPath1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs"
if (-not (Test-Path $regPath1)) {
    New-Item -Path $regPath1 -Force | Out-Null
}
New-ItemProperty -Path $regPath1 -Name "NoProgramsAndFeatures" -Value 1 -PropertyType DWORD -Force | Out-Null

# 2. Hide "Installed apps" page in Settings app (Windows 10/11)
$regPath2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (-not (Test-Path $regPath2)) {
    New-Item -Path $regPath2 -Force | Out-Null
}
New-ItemProperty -Path $regPath2 -Name "SettingsPageVisibility" -Value "hide:appsfeatures" -PropertyType String -Force | Out-Null

# 3. Optional: Disable Windows Installer for non-admins (blocks most MSI-based installations)
# This applies system-wide but admins can still install.
$regPath3 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
if (-not (Test-Path $regPath3)) {
    New-Item -Path $regPath3 -Force | Out-Null
}
New-ItemProperty -Path $regPath3 -Name "DisableMSI" -Value 1 -PropertyType DWORD -Force | Out-Null
# Value 1 = Disable for non-managed apps (standard users can't install MSI without elevation)
# Value 2 = Completely disable (not recommended, breaks admin installs too)

Write-Host "Restrictions applied. Restart the computer or log out/in for changes to take effect."
Write-Host "Standard users will no longer see options to install/uninstall most programs."
Write-Host "Admins remain unaffected."

# To revert:
# Remove-ItemProperty -Path $regPath1 -Name "NoProgramsAndFeatures"
# Remove-ItemProperty -Path $regPath2 -Name "SettingsPageVisibility"
# Remove-ItemProperty -Path $regPath3 -Name "DisableMSI"