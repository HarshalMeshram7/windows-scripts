# Check if the current user is an Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "You are an administrator. No restrictions applied."
} else {
    Write-Host "Standard user detected. Applying restrictions..."

    try {
        # Restrict software installation using Windows Installer policy
        $regPath = "HKCU:\Software\Policies\Microsoft\Windows\Installer"

        # Create the key if it doesn't exist
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        # Set policy: Always install with elevated privileges = 0 (disabled)
        Set-ItemProperty -Path $regPath -Name "AlwaysInstallElevated" -Value 0 -Type DWord

        # Disable Windows Installer for the user
        Set-ItemProperty -Path $regPath -Name "DisableMSI" -Value 1 -Type DWord

        Write-Host "Installation and uninstallation restrictions applied successfully."
    } catch {
        Write-Host "Failed to apply restrictions: $_"
    }
}
