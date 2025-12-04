<#
    AUTOMATED PARENTAL CONTROL ONBOARDING SCRIPT (FIXED PASSWORD VERSION)
    ---------------------------------------------------------------------
    This script:
    1. Detects Microsoft Account child account
    2. Creates ParentAdmin (local admin)
    3. Password: Pass@123
    4. Downgrades child account to Standard User
    5. Logs out child immediately
    6. Returns JSON summary
#>

# -----------------------------------------------
# 1. Detect Child Microsoft Account
# -----------------------------------------------

$msaUsers = Get-LocalUser | Where-Object { $_.PrincipalSource -eq "MicrosoftAccount" }

if ($msaUsers.Count -eq 0) {
    Write-Host "ERROR: No Microsoft Account found on device. Cannot proceed." -ForegroundColor Red
    exit
}

# Primary Microsoft Account (child)
$ChildAccount = $msaUsers[0].Name
$ChildUsername = ($ChildAccount -split "\\")[-1]

# -----------------------------------------------
# 2. Create Parent Admin (local admin)
# -----------------------------------------------

$ParentAdmin = "ParentAdmin"
$ParentPassword = "Pass@123"        # FIXED PASSWORD
$ParentSecurePass = ConvertTo-SecureString $ParentPassword -AsPlainText -Force

# Create account if not exists
try {
    New-LocalUser -Name $ParentAdmin -Password $ParentSecurePass `
    -FullName "Parent Administrator" `
    -Description "Local Parent Admin for Parental Control"

    Add-LocalGroupMember -Group "Administrators" -Member $ParentAdmin

    Write-Host "ParentAdmin created."
}
catch {
    Write-Host "ParentAdmin already exists. Updating password..."
    Set-LocalUser -Name $ParentAdmin -Password $ParentSecurePass
}

# -----------------------------------------------
# 3. Downgrade Child From Admin → Standard User
# -----------------------------------------------

try {
    Remove-LocalGroupMember -Group "Administrators" -Member $ChildUsername -ErrorAction Stop
}
catch {
    Write-Host "Child user already not in Administrators group."
}

try {
    Add-LocalGroupMember -Group "Users" -Member $ChildUsername -ErrorAction SilentlyContinue
}
catch {}

$result = @{
    status              = "success"
    child_account       = $ChildUsername
    parent_admin        = $ParentAdmin
    parent_admin_pass   = $ParentPassword
    note                = "Child downgraded to Standard User. ParentAdmin is full administrator."
}

$result | ConvertTo-Json -Depth 4


# -----------------------------------------------
# 4. Log Out Child Immediately
# -----------------------------------------------

Start-Process "shutdown.exe" -ArgumentList "/l"

# -----------------------------------------------
# 5. Return JSON Summary (for MDM backend)
# -----------------------------------------------

