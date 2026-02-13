$AppNames = @(
    "chrome",
    "zoom",
    "postman",
    "notepad++"
)

$DebuggerPath = 'mshta.exe "javascript:alert(''This application has been blocked by your administrator.'');close();"'

foreach ($app in $AppNames) {

    # Automatically append .exe
    $exeName = "$app.exe"

    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

    New-Item -Path $RegPath -Force | Out-Null
    New-ItemProperty `
        -Path $RegPath `
        -Name "Debugger" `
        -PropertyType String `
        -Value $DebuggerPath `
        -Force | Out-Null

    Write-Host "BLOCKED: $exeName" -ForegroundColor Red
}

Write-Host "---- Completed Blocking Applications ----"
