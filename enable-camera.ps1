# Requires running as Administrator

# Find all disabled camera devices
$cameras = Get-PnpDevice -Class Camera, Image | Where-Object { $_.Status -eq 'Error' -or $_.Status -eq 'Disabled' }

if ($cameras.Count -eq 0) {
    Write-Host "No disabled camera devices found." -ForegroundColor Yellow
    Write-Host "All cameras appear to be already enabled." -ForegroundColor Cyan
} else {
    Write-Host "Found $($cameras.Count) disabled camera device(s):" -ForegroundColor Cyan
    $cameras | Select-Object FriendlyName, InstanceId, Status | Format-Table

    # Enable them (suppress confirmation prompt)
    $cameras | Enable-PnpDevice -Confirm:$false

    Write-Host "Camera device(s) have been successfully re-enabled." -ForegroundColor Green
    Write-Host "Note: Some applications may need to be restarted to detect the camera." -ForegroundColor Yellow
}