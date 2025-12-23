# ---------------------------------------------
# Create a standard user "Child" with predefined password and sign out current user
# ---------------------------------------------

# Run as Administrator check
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run PowerShell as Administrator."
    exit
}

# Set username and password for new user
$Username = "Child"
$PlainPassword = "Child@123"

# Convert plain password to secure string
$Password = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

# Check if user already exists
if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Write-Warning "User '$Username' already exists."
} else {
    # Create new standard user
    New-LocalUser -Name $Username -Password $Password -FullName "Child Account" -Description "Standard child account"
    Add-LocalGroupMember -Group "Users" -Member $Username
    Write-Output "User '$Username' created as standard user with password '$PlainPassword'."
}

# Sign out current user
Write-Output "Signing out current user..."
shutdown.exe /l
