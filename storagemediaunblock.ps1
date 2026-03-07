Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 3

Write-Host "USB storage devices are enabled again." -ForegroundColor Green