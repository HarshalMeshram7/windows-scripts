# ==========================================
# Unblock Multiple Applications using IFEO
# ==========================================

$ExeNamesToUnblock = @(
    "chrome.exe",
    "notepad++.exe",
    "zoom.exe",
    "postman.exe"
)

foreach ($exe in $ExeNamesToUnblock) {

    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe"

    if (Test-Path $RegPath) {
        Remove-Item -Path $RegPath -Recurse -Force
        Write-Host "UNBLOCKED: $exe" -ForegroundColor Green
    }
    else {
        Write-Host "SKIPPED: $exe (not blocked)" -ForegroundColor Yellow
    }
}

Write-Host "---- Completed Unblocking Apps ----" -ForegroundColor Cyan
