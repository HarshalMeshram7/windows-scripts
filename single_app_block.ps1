# ==========================================
# Block Multiple Applications using IFEO
# Supports HKLM + HKCU + HKCR fallback
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
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($AppName in $AppsToBlock) {

    $exePath = $null
    $exeName = $null

    # -------- STEP 1: Try Uninstall keys --------
    $app = foreach ($key in $UninstallKeys) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$AppName*" }
    }

    if ($app -and $app.DisplayIcon) {
        $exePath = $app.DisplayIcon.Split(',')[0]
    }

    # -------- STEP 2: HKCR fallback (Postman, Discord etc.) --------
    if (-not $exePath) {
        $hkcrPath = "Registry::HKEY_CLASSES_ROOT\$($AppName.ToLower())\shell\open\command"
        if (Test-Path $hkcrPath) {
            $command = (Get-ItemProperty $hkcrPath).'(default)'
            if ($command) {
                $exePath = ($command -replace '^"|".*$', '')
            }
        }
    }

    if (-not $exePath) {
        Write-Host "SKIPPED: $AppName (EXE path not found)" -ForegroundColor Yellow
        continue
    }

    $exeName = [System.IO.Path]::GetFileName($exePath)

    if (-not $exeName) {
        Write-Host "SKIPPED: $AppName (invalid EXE)" -ForegroundColor Yellow
        continue
    }

    # -------- STEP 3: IFEO block --------
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

    New-Item -Path $RegPath -Force | Out-Null
    New-ItemProperty `
        -Path $RegPath `
        -Name "Debugger" `
        -PropertyType String `
        -Value $DebuggerPath `
        -Force | Out-Null

    Write-Host "BLOCKED: $AppName ($exeName)" -ForegroundColor Red
}

Write-Host "---- Completed Blocking Apps ----" -ForegroundColor Cyan
