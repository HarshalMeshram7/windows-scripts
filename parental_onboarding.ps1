# ==============================
# Child local account creation
# Reliable on Windows 10 / 11
# Auto sign-out at the end
# ==============================

$Username    = "Child"
$Password    = "Child@123"
$FullName    = "Child User"
$Description = "Standard child account"

Write-Host "Starting child account setup..."

# Check if user already exists
$existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

if ($existingUser) {
    Write-Host "User '$Username' already exists. Removing corrupted account..."
    Remove-LocalUser -Name $Username
    Start-Sleep -Seconds 2
}

# Create user using Windows account engine
Write-Host "Creating user '$Username'..."
cmd /c "net user $Username $Password /add"

# Set full name and description
cmd /c "net user $Username /fullname:`"$FullName`" /comment:`"$Description`""

# Ensure user is NOT an administrator
cmd /c "net localgroup Administrators $Username /delete" 2>$null

# Explicitly enable account
Enable-LocalUser -Name $Username

# Verify result
$user = Get-LocalUser -Name $Username
$user | Select Name, Enabled, PasswordRequired | Format-Table -AutoSize

Write-Host "Account setup complete."
Write-Host "Signing out current user in 5 seconds..."

#---- Blocking Browsers -------

$AppNames = @(
    "chrome",
    "msedge",
    "firefox",
    "brave",
    "opera",
    "vivaldi",
    "iexplore",
    "tor"
)

$DebuggerPath = 'mshta.exe "javascript:alert(''This application has been blocked by your administrator.'');close();"'

foreach ($app in $AppNames) {

    # Automatically append .exe
    $exeName = "$app.exe"

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

Write-Host "---- Completed Blocking Applications ----"

# Sign out current user
shutdown /l
