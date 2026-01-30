# ==========================================
# Block Multiple Applications using IFEO
# ==========================================

$AppsToBlock = @(
    "Google Chrome",
    "Notepad++",
    "Zoom",
    "Postman"
)

$DebuggerPath = "C:\Windows\System32\systray.exe"

$UninstallKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($AppName in $AppsToBlock) {

    $app = foreach ($key in $UninstallKeys) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$AppName*" }
    }

    if (-not $app) {
        Write-Host "SKIPPED: $AppName (not found)" -ForegroundColor Yellow
        continue
    }

    if (-not $app.DisplayIcon) {
        Write-Host "SKIPPED: $AppName (no EXE path found)" -ForegroundColor Yellow
        continue
    }

    $exePath = $app.DisplayIcon.Split(',')[0]
    $exeName = [System.IO.Path]::GetFileName($exePath)

    if (-not $exeName) {
        Write-Host "SKIPPED: $AppName (invalid EXE)" -ForegroundColor Yellow
        continue
    }

    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

    New-Item -Path $RegPath -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name "Debugger" -PropertyType String -Value $DebuggerPath -Force | Out-Null

    Write-Host "BLOCKED: $($app.DisplayName) ($exeName)" -ForegroundColor Red
}

Write-Host "---- Completed Blocking Apps ----" -ForegroundColor Cyan
