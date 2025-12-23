# Get the local Administrators group members
$AdminSIDs = Get-LocalGroupMember -Group "Administrators" |
    Where-Object { $_.ObjectClass -eq "User" } |
    ForEach-Object { $_.SID.Value }

# Get all enabled local users
$Users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

foreach ($User in $Users) {

    # Skip administrators
    if ($AdminSIDs -contains $User.SID.Value) {
        Write-Output "Skipping administrator user: $($User.Name)"
        continue
    }

    # Webcam privacy registry path
    $RegPath = "Registry::HKEY_USERS\$($User.SID.Value)\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"

    # Only change if the key exists
    if (Test-Path $RegPath) {
        Set-ItemProperty -Path $RegPath -Name "Value" -Value "Allow"
        Write-Output "Camera ENABLED for standard user: $($User.Name)"
    }
    else {
        Write-Output "No camera restriction found for user: $($User.Name)"
    }
}

Write-Output "Camera access has been restored for all standard users."
