# ==============================
# Child local account creation
# Reliable on Windows 10 / 11
# Auto sign-out at the end
# ==============================

$Username    = "Child"
$Password    = "Child@123"
$FullName    = "Child User"
$Description = "Standard child account"

# ==============================
# LOGGER SETUP
# ==============================
$LogDir  = "C:\Logs"
$LogFile = "$LogDir\ChildAccountSetup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $LogFile -Value $line

    # Also write to console with color
    switch ($Level) {
        "SUCCESS" { Write-Host $line -ForegroundColor Green  }
        "WARNING" { Write-Host $line -ForegroundColor Yellow }
        "ERROR"   { Write-Host $line -ForegroundColor Red    }
        default   { Write-Host $line                         }
    }
}

function Write-LogSeparator {
    $line = "=" * 60
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

# ==============================
# START
# ==============================
Write-LogSeparator
Write-Log "Script started by user: $env:USERNAME on machine: $env:COMPUTERNAME"
Write-Log "Log file location: $LogFile"
Write-LogSeparator

# ---- STEP 1: Check existing user ----
Write-Log "STEP 1: Checking if user '$Username' already exists..."
try {
    $existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Log "User '$Username' already exists. Removing corrupted account..." "WARNING"
        Remove-LocalUser -Name $Username
        Start-Sleep -Seconds 2
        Write-Log "Existing user '$Username' removed successfully." "SUCCESS"
    } else {
        Write-Log "No existing user '$Username' found. Proceeding." "INFO"
    }
} catch {
    Write-Log "ERROR during user check/removal: $_" "ERROR"
}

# ---- STEP 2: Create user ----
Write-Log "STEP 2: Creating user '$Username'..."
try {
    $result = cmd /c "net user $Username $Password /add" 2>&1
    Write-Log "net user output: $result"
    $checkUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($checkUser) {
        Write-Log "User '$Username' created successfully." "SUCCESS"
    } else {
        Write-Log "User '$Username' was NOT found after creation attempt. Check permissions." "ERROR"
    }
} catch {
    Write-Log "ERROR creating user: $_" "ERROR"
}

# ---- STEP 3: Set full name and description ----
Write-Log "STEP 3: Setting full name and description..."
try {
    $result = cmd /c "net user $Username /fullname:`"$FullName`" /comment:`"$Description`"" 2>&1
    Write-Log "net user (fullname/comment) output: $result"
    Write-Log "Full name and description set." "SUCCESS"
} catch {
    Write-Log "ERROR setting full name/description: $_" "ERROR"
}

# ---- STEP 4: Remove from Administrators ----
Write-Log "STEP 4: Ensuring '$Username' is NOT in Administrators group..."
try {
    $result = cmd /c "net localgroup Administrators $Username /delete" 2>&1
    if ($result -match "successfully") {
        Write-Log "Removed '$Username' from Administrators group." "SUCCESS"
    } else {
        Write-Log "Admin removal result: $result (user may not have been in Administrators)" "INFO"
    }
} catch {
    Write-Log "ERROR removing from Administrators: $_" "ERROR"
}

# ---- STEP 5: Enable account ----
Write-Log "STEP 5: Enabling account '$Username'..."
try {
    Enable-LocalUser -Name $Username
    Write-Log "Account '$Username' enabled successfully." "SUCCESS"
} catch {
    Write-Log "ERROR enabling account: $_" "ERROR"
}

# ---- STEP 6: Verify account ----
Write-Log "STEP 6: Verifying account details..."
try {
    $user = Get-LocalUser -Name $Username
    Write-Log "Name: $($user.Name) | Enabled: $($user.Enabled) | PasswordRequired: $($user.PasswordRequired)" "INFO"
    Write-Log "Account verification complete." "SUCCESS"
} catch {
    Write-Log "ERROR verifying account: $_" "ERROR"
}

# ---- STEP 7: Block browsers ----
Write-LogSeparator
Write-Log "STEP 7: Blocking browsers via Image File Execution Options..."

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
    $exeName = "$app.exe"
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"
    try {
        New-Item -Path $RegPath -Force | Out-Null
        New-ItemProperty `
            -Path $RegPath `
            -Name "Debugger" `
            -PropertyType String `
            -Value $DebuggerPath `
            -Force | Out-Null
        Write-Log "BLOCKED: $exeName" "SUCCESS"
    } catch {
        Write-Log "FAILED to block $exeName : $_" "ERROR"
    }
}

Write-Log "Browser blocking complete." "SUCCESS"

# ---- STEP 8: Sign out ----
Write-LogSeparator
Write-Log "STEP 8: All steps completed. Restarting system in 5 seconds..."
Write-Log "Script finished. Log saved at: $LogFile" "SUCCESS"
Write-LogSeparator

Start-Sleep -Seconds 5
shutdown /r /t 0 /f