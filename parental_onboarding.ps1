# Variables
$username = "Child"
$password = "Child@123"

# Convert password to secure string
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

# Check if user already exists
if (Get-LocalUser -Name $username -ErrorAction SilentlyContinue) {
    Write-Host "User '$username' already exists."
} else {
    # Create standard local user
    New-LocalUser `
        -Name $username `
        -Password $securePassword `
        -FullName "Child User" `
        -Description "Standard child account"

    Write-Host "User '$username' created successfully."
}

# Ensure user is NOT an administrator (standard user)
Remove-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue

# Sign out current user
Write-Host "Signing out current user..."
shutdown /l
