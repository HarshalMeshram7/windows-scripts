# ============================================================
# FINAL: Block Multiple Applications using IFEO
# Sources:
# 1. HKLM Uninstall
# 2. HKCU Uninstall
# 3. HKCR protocol handler
# 4. MuiCache (LAST fallback)
# ============================================================

$AppsToBlock = @(
    "Google Chrome",
    "Notepad++",
    "Zoom",
    "Postman"
)

$DebuggerPath = "cmd.exe"

$UninstallKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$MuiCachePath = "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"

foreach ($AppName in $AppsToBlock) {

    $exePath = $null
    $exeName = $null

    # -------------------------------
    # 1️⃣ HKLM / HKCU Uninstall
    # -------------------------------
    foreach ($key in $UninstallKeys) {
        $app = Get-ItemProperty $key -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -like "*$AppName*" }

        if ($app -and $app.DisplayIcon) {
            $exePath = $app.DisplayIcon.Split(',')[0]
            break
        }
    }

    # -------------------------------
    # 2️⃣ HKCR protocol handler
    # -------------------------------
    if (-not $exePath) {
        $protocolKey = "Registry::HKEY_CLASSES_ROOT\$($AppName.ToLower())\shell\open\command"
        if (Test-Path $protocolKey) {
            $command = (Get-ItemProperty $protocolKey).'(default)'
            if ($command) {
                $exePath = ($command -replace '^"|".*$', '')
            }
        }
    }

    # -------------------------------
    # 3️⃣ MuiCache (last fallback)
    # -------------------------------
    if (-not $exePath -and (Test-Path $MuiCachePath)) {
        $muiEntries = Get-ItemProperty $MuiCachePath
        foreach ($prop in $muiEntries.PSObject.Properties) {
            if ($prop.Name -match '\.exe' -and $prop.Name -match $AppName) {
                $exePath = $prop.Name
                break
            }
        }
    }

    # -------------------------------
    # Validation
    # -------------------------------
    if (-not $exePath) {
        Write-Host "SKIPPED: $AppName (EXE path not found)" -ForegroundColor Yellow
        continue
    }

    $exeName = [System.IO.Path]::GetFileName($exePath)

    if (-not $exeName) {
        Write-Host "SKIPPED: $AppName (invalid EXE)" -ForegroundColor Yellow
        continue
    }

    # -------------------------------
    # 4️⃣ IFEO Block
    # -------------------------------
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

Write-Host "---- Completed Blocking Applications ----" -ForegroundColor Cyan
