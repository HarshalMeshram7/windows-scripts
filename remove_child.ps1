# -------- CONFIG --------
$UserName = "Child"
# ------------------------

# Check if the user exists
$user = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue

if ($null -eq $user) {
    Write-Host "User '$UserName' does not exist." -ForegroundColor Yellow
    exit
}

# Remove the user account
Remove-LocalUser -Name $UserName
Write-Host "User account '$UserName' has been removed." -ForegroundColor Green

# Remove the user profile folder (optional but recommended)
$profilePath = "C:\Users\$UserName"

if (Test-Path $profilePath) {
    Remove-Item -Path $profilePath -Recurse -Force
    Write-Host "Profile folder '$profilePath' has been deleted." -ForegroundColor Green
} else {
    Write-Host "No profile folder found for '$UserName'." -ForegroundColor Cyan
}
