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

# ---- STEP 7: Block browsers and store ----
Write-LogSeparator
Write-Log "STEP 7: Blocking browsers via Image File Execution Options..."

$AppNames = @(
    "store",
    "chrome",
    "msedge",
    "firefox",
    "brave",
    "opera",
    "vivaldi",
    "iexplore",
    "tor"
)

# ============================================================
# CLEAN UP APP NAMES
# ============================================================

$AppNames = $AppNames | ForEach-Object { $_.Trim().Trim(',') } | Where-Object { $_ -ne "" }
Write-Log "Cleaned app names: $($AppNames -join ', ')" "INFO"

$blockedExe   = @()
$blockedStore = @()
$foundApps    = @()

$DebuggerPath = 'mshta.exe "javascript:alert(''This application has been blocked by your administrator.'');close();"'

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "        Auto-Detecting App Types        " -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta
Write-Log "--- Auto-detecting app types ---" "INFO"

# ============================================================
# DETECT APP TYPES
# ============================================================

foreach ($app in $AppNames) {

    # ---- Check if it's a Store/UWP app first ----
    $pkg = Get-AppxPackage | Where-Object { $_.Name -eq $app } | Select-Object -First 1
    if (-not $pkg) {
        $pkg = Get-AppxPackage | Where-Object { $_.Name -like "*$app*" } | Select-Object -First 1
    }

    if ($pkg) {
        Write-Host "  [STORE]  Detected: $($pkg.Name)" -ForegroundColor Cyan
        Write-Log "Detected as STORE app: $($pkg.Name) (input: '$app')" "INFO"
        $foundApps    += $pkg.Name
        $blockedStore += $app
    } else {
        Write-Host "  [EXE]    Detected: $app" -ForegroundColor DarkYellow
        Write-Log "Detected as EXE app: $app" "INFO"
        $blockedExe += $app
    }
}

# ============================================================
# PART 1: Block EXE Apps via Registry
# ============================================================

if ($blockedExe.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "   Blocking EXE Apps via Registry...   " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Log "--- Blocking EXE apps via Registry ---" "INFO"

    foreach ($app in $blockedExe) {
        $cleanName = $app -replace '\.exe$', ''
        $exeName   = "$cleanName.exe"
        $RegPath   = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"

        try {
            New-Item -Path $RegPath -Force | Out-Null
            New-ItemProperty `
                -Path $RegPath `
                -Name "Debugger" `
                -PropertyType String `
                -Value $DebuggerPath `
                -Force | Out-Null

            Write-Host "  BLOCKED (EXE): $exeName" -ForegroundColor Red
            Write-Log "Successfully blocked EXE app via registry: $exeName  |  RegPath: $RegPath" "SUCCESS"
        }
        catch {
            Write-Host "  FAILED to block (EXE): $exeName" -ForegroundColor Red
            Write-Log "Failed to block EXE app '$exeName'. Error: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ============================================================
# PART 2: Block Store Apps via AppLocker
# ============================================================

if ($foundApps.Count -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Blocking Store Apps via AppLocker...  " -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Log "--- Blocking Store apps via AppLocker ---" "INFO"

    Write-Host "`nGenerating AppLocker rules..." -ForegroundColor Cyan
    Write-Log "Generating AppLocker rules for $($foundApps.Count) app(s)..." "INFO"

    # Allow All rule (required)
    $allowRuleId = [System.Guid]::NewGuid().ToString()
    Write-Log "Generated Allow-All rule UUID: $allowRuleId" "INFO"

    $rulesXml = @"
    <!-- Allow All (Required) -->
    <FilePublisherRule Id="$allowRuleId"
      Name="Allow All Signed Packaged Apps"
      Description="Allow all signed packaged apps by default"
      UserOrGroupSid="S-1-1-0"
      Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
"@

    foreach ($productName in $foundApps) {
        $ruleId = [System.Guid]::NewGuid().ToString()
        Write-Host "  Generated UUID $ruleId --> $productName" -ForegroundColor DarkCyan
        Write-Log "Generated Deny rule UUID: $ruleId  |  App: $productName" "INFO"

        $rulesXml += @"

    <!-- Deny $productName -->
    <FilePublisherRule Id="$ruleId"
      Name="Block $productName"
      Description="Block $productName for all users"
      UserOrGroupSid="S-1-1-0"
      Action="Deny">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="$productName" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
"@
    }

    $fullPolicy = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
$rulesXml
  </RuleCollection>
</AppLockerPolicy>
"@

    $policyPath = "C:\AppLockerPolicy.xml"

    try {
        $fullPolicy | Out-File $policyPath -Encoding UTF8
        Write-Host "`nPolicy saved to $policyPath" -ForegroundColor Cyan
        Write-Log "AppLocker policy XML saved to: $policyPath" "SUCCESS"
    }
    catch {
        Write-Log "Failed to save AppLocker policy XML to '$policyPath'. Error: $($_.Exception.Message)" "ERROR"
    }

    try {
        Set-AppLockerPolicy -XmlPolicy $policyPath -Merge
        Write-Host "AppLocker policy applied!" -ForegroundColor Green
        Write-Log "AppLocker policy applied successfully (merged)." "SUCCESS"
    }
    catch {
        Write-Host "Failed to apply AppLocker policy!" -ForegroundColor Red
        Write-Log "Failed to apply AppLocker policy. Error: $($_.Exception.Message)" "ERROR"
    }

    try {
        $scConfigResult = sc.exe config AppIDSvc start= auto 2>&1
        $scStartResult  = sc.exe start  AppIDSvc        2>&1

        Write-Host "AppIDSvc service started!" -ForegroundColor Green
        Write-Log "AppIDSvc configured to Auto-start. Config output: $scConfigResult" "SUCCESS"
        Write-Log "AppIDSvc start output: $scStartResult" "INFO"
    }
    catch {
        Write-Host "Warning: Could not start AppIDSvc." -ForegroundColor Yellow
        Write-Log "Warning: Failed to configure/start AppIDSvc. Error: $($_.Exception.Message)" "WARNING"
    }
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "             BLOCK SUMMARY              " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Log "--- Block Summary ---" "INFO"

if ($blockedExe.Count -gt 0) {
    Write-Host "`nEXE Apps Blocked (Registry):" -ForegroundColor Yellow
    $blockedExe | ForEach-Object {
        Write-Host "  - $_.exe" -ForegroundColor Red
        Write-Log "EXE blocked: $_.exe" "SUCCESS"
    }
}

if ($foundApps.Count -gt 0) {
    Write-Host "`nStore Apps Blocked (AppLocker):" -ForegroundColor Yellow
    $foundApps | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
        Write-Log "Store app blocked: $_" "SUCCESS"
    }
}

if ($blockedExe.Count -eq 0 -and $foundApps.Count -eq 0) {
    Write-Host "`nNo apps were blocked." -ForegroundColor Yellow
    Write-Log "No apps were blocked. Check input names and try again." "WARNING"
}

Write-Host "`n---- Completed Blocking Applications ----`n" -ForegroundColor Green
Write-Log "Script completed. EXE blocked: $($blockedExe.Count) | Store blocked: $($foundApps.Count)" "SUCCESS"
Write-Log "Full log saved to: $LogFile" "INFO"
Add-Content -Path $LogFile -Value "========================================"

# ---- STEP 8: Sign out ----
Write-LogSeparator
Write-Log "STEP 8: All steps completed. Restarting system in 5 seconds..."
Write-Log "Script finished. Log saved at: $LogFile" "SUCCESS"
Write-LogSeparator


##########################################################################################
#########################################################################################
# Disable USB Mass Storage driver
try {

    # Block USB storage
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 4

    Stop-Service -Name USBSTOR -Force -ErrorAction SilentlyContinue

    Write-Log "USB storage devices BLOCKED successfully"

    Write-Host "USB storage devices blocked successfully" -ForegroundColor Green
}
catch {

    Write-Log "ERROR blocking USB storage: $_"

    Write-Host "Error occurred. Check log file." -ForegroundColor Red
}


########################################################################################################

# Run as Administrator

Write-Host "Checking Winget installation..." -ForegroundColor Cyan

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Winget is already installed." -ForegroundColor Green
} else {
    Write-Host "Winget not found. Installing App Installer from Microsoft Store..." -ForegroundColor Yellow
    Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
    Write-Host "Follow the installer prompt to complete Winget installation."
}

Write-Host "`nChecking Chocolatey installation..." -ForegroundColor Cyan

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = 3072

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    Write-Host "Chocolatey installation completed." -ForegroundColor Green
}

Write-Host "`nVerifying installations..." -ForegroundColor Cyan

winget --version
choco -v

Write-Host "`nSetup Complete!" -ForegroundColor Green

############################################################################################################
Start-Sleep -Seconds 5
shutdown /r /t 0 /f