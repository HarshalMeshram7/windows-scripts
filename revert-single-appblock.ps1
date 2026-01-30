# ==========================================
# Unblock Multiple Applications using IFEO
# ==========================================

$ExeNamesToUnblock = @(
    "chrome.exe",
    "notepad++.exe",
    "zoom.exe",
    "postman.exe"
)

foreach ($exeName in $ExeNamesToUnblock) {

    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

    if (Test-Path $RegPath) {
        Remove-Item -Path $RegPath -Recurse -Force
        Write-Host "UNBLOCKED: $exeName" -ForegroundColor Green
    }
    else {
        Write-Host "SKIPPED: $exeName (not blocked)" -ForegroundColor Yellow
    }
}

Write-Host "---- Completed Unblocking Apps ----" -ForegroundColor Cyan
