# ================================
# REQUIRE ADMIN
# ================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run this script as Administrator"
    exit 1
}

Write-Host "Running as Administrator"

# ================================
# BLOCK CHROME USING IFEO
# ================================
$exe = "chrome.exe"

$ifeoPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe"
)

foreach ($path in $ifeoPaths) {
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty `
        -Path $path `
        -Name Debugger `
        -Value "C:\Windows\System32\blocked.exe" `
        -Type String

    Write-Host "IFEO block applied at $path"
}

Write-Host "Chrome is now BLOCKED"
Write-Host "Reboot required"

shutdown /r /t 5
