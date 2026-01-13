# Run as Administrator

$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_AssignedAccess"

Write-Host "Removing kiosk configuration..."

$obj = Get-CimInstance -Namespace $namespaceName -ClassName $className -ErrorAction SilentlyContinue

if ($obj) {
    $obj.Configuration = $null
    Set-CimInstance -CimInstance $obj
    Write-Host "Kiosk configuration removed."
} else {
    Write-Host "No kiosk configuration found."
}

# Remove kiosk user
$user = "temp"
if (Get-LocalUser -Name $user -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $user
    Write-Host "User '$user' removed."
} else {
    Write-Host "User '$user' not found."
}

Write-Host "Kiosk removed successfully. Please reboot the system."
