param (
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Apps
)

Write-Host "---- Starting App Unblock ----" -ForegroundColor Cyan

foreach ($app in $Apps) {

    # Auto-append .exe if not provided
    if ($app -notmatch '\.exe$') {
        $exeName = "$app.exe"
    } else {
        $exeName = $app
    }

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


## .\revert-single-appblock.ps1 chrome postman discord
