# PowerShell script to REVERT the restrictions applied by the previous script
# This removes the registry keys that blocked install/uninstall functionality for standard users
# Run this script as Administrator

# 1. Remove the "NoProgramsAndFeatures" restriction (unhide Programs and Features in Control Panel)
$regPath1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Programs"
if (Test-Path $regPath1) {
    Remove-ItemProperty -Path $regPath1 -Name "NoProgramsAndFeatures" -ErrorAction SilentlyContinue
}

# 2. Remove the "SettingsPageVisibility" restriction (unhide Installed apps in Settings)
$regPath2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (Test-Path $regPath2) {
    Remove-ItemProperty -Path $regPath2 -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue
}

# 3. Remove the "DisableMSI" restriction (re-enable MSI installations for standard users)
$regPath3 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
if (Test-Path $regPath3) {
    Remove-ItemProperty -Path $regPath3 -Name "DisableMSI" -ErrorAction SilentlyContinue
}

# Optional: Clean up empty parent keys (harmless if they contain other values)
# Remove-Item -Path $regPath1 -Recurse -ErrorAction SilentlyContinue
# Remove-Item -Path $regPath3 -Recurse -ErrorAction SilentlyContinue

Write-Host "All restrictions have been removed."
Write-Host "Standard users can now access install/uninstall options again."
Write-Host "Restart the computer or log out/in for changes to take full effect."