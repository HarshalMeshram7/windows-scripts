$LogFile = "C:\ProgramData\safe4sure_protection.log"

function Write-Log {
    param([string]$msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $LogFile "$time - $msg"
}

Write-Log "Blocking AppX uninstall for standard users"

$policy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx"

New-Item -Path $policy -Force | Out-Null

New-ItemProperty `
-Path $policy `
-Name "AllowAllTrustedApps" `
-Value 1 `
-PropertyType DWORD `
-Force | Out-Null

New-ItemProperty `
-Path $policy `
-Name "BlockNonAdminUserInstall" `
-Value 1 `
-PropertyType DWORD `
-Force | Out-Null

Write-Log "AppX uninstall restriction applied"