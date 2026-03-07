# Disable USB Mass Storage driver
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 4

# Stop the service if running
Stop-Service -Name USBSTOR -Force -ErrorAction SilentlyContinue

Write-Host "USB storage devices (pendrives / external HDD) are now blocked." -ForegroundColor Green