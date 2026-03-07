$LogFile = "C:\ProgramData\safe4sure_protection.log"

function Write-Log {
    param([string]$msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $LogFile "$time - $msg"
}

Write-Log "Reverting AppX uninstall restriction"

$policy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx"

if (Test-Path $policy) {

    Remove-ItemProperty `
    -Path $policy `
    -Name "AllowAllTrustedApps" `
    -ErrorAction SilentlyContinue

    Remove-ItemProperty `
    -Path $policy `
    -Name "BlockNonAdminUserInstall" `
    -ErrorAction SilentlyContinue

    Write-Log "AppX policies removed"

    # Remove key if empty
    if ((Get-Item $policy).Property.Count -eq 0) {
        Remove-Item $policy -Force
        Write-Log "AppX policy key removed"
    }
}

gpupdate /force | Out-Null

Write-Log "AppX uninstall restriction reverted"
Write-Log "-----------------------------------"