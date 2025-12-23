# Get the local Administrators group members
$AdminSIDs = Get-LocalGroupMember -Group "Administrators" |
    Where-Object { $_.ObjectClass -eq "User" } |
    ForEach-Object { $_.SID.Value }

# Get all local users
$Users = Get-LocalUser | Where-Object { $_.Enabled -eq $true }

foreach ($User in $Users) {

    # Skip administrators
    if ($AdminSIDs -contains $User.SID.Value) {
        Write-Output "Skipping administrator user: $($User.Name)"
        continue
    }

    # Registry path for webcam privacy
    $RegPath = "Registry::HKEY_USERS\$($User.SID.Value)\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"

    # Create registry path if missing
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    # Disable camera
    Set-ItemProperty -Path $RegPath -Name "Value" -Value "Deny"

    Write-Output "Camera DISABLED for standard user: $($User.Name)"
}

Write-Output "Camera restriction applied to all standard users."
