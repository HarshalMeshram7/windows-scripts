# Requires running as Administrator

# Find all enabled camera devices
$cameras = Get-PnpDevice -Class Camera, Image -Status OK

if ($cameras.Count -eq 0) {
    Write-Host "No enabled camera devices found." -ForegroundColor Yellow
} else {
    Write-Host "Found $($cameras.Count) enabled camera device(s):" -ForegroundColor Cyan
    $cameras | Select-Object FriendlyName, InstanceId | Format-Table

    # Disable them (suppress confirmation prompt)
    $cameras | Disable-PnpDevice -Confirm:$false

    Write-Host "Camera device(s) have been disabled." -ForegroundColor Green
    Write-Host "To re-enable, run: Get-PnpDevice -Class Camera, Image | Enable-PnpDevice -Confirm:`$false" -ForegroundColor Yellow
}