param (
    [Parameter(Mandatory = $true)]
    [string[]]$AppNames
)

$DebuggerPath = 'mshta.exe "javascript:alert(''This application has been blocked by your administrator.'');close();"'


foreach ($app in $AppNames) {

    # Normalize name (remove .exe if user passed it)
    $cleanName = $app -replace '\.exe$', ''

    $exeName = "$cleanName.exe"

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

Write-Host "---- Completed Blocking Applications ----" -ForegroundColor Green


#### run this file like
## .\single_app_block.ps1 chrome postman zoom notepad++
