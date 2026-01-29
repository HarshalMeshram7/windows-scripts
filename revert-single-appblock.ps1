# ==================================================
# UNBLOCK EVERYTHING - MDM EMERGENCY RECOVERY
# Must run as SYSTEM / Administrator
# ==================================================

Write-Output "=== STARTING FULL UNBLOCK ==="

# --------------------------------------------------
# 1. REMOVE ALL IFEO BLOCKS (Execution Blocking)
# --------------------------------------------------
$ifeoRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
)

foreach ($root in $ifeoRoots) {
    if (-not (Test-Path $root)) { continue }

    Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
            if ($props.Debugger) {
                Remove-Item $_.PsPath -Recurse -Force
                Write-Output "Removed IFEO: $($_.PSChildName)"
            }
        } catch {}
    }
}

# --------------------------------------------------
# 2. REMOVE EXPLORER RESTRICTIONS (USER + MACHINE)
# --------------------------------------------------

# Machine-level
$machineExplorer = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (Test-Path $machineExplorer) {
    Remove-ItemProperty -Path $machineExplorer -Name DisallowRun -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $machineExplorer -Name RestrictRun -ErrorAction SilentlyContinue
    Remove-Item "$machineExplorer\DisallowRun" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$machineExplorer\RestrictRun" -Recurse -Force -ErrorAction SilentlyContinue
}

# User-level (ALL users)
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

Get-ChildItem HKU:\ | Where-Object {
    $_.Name -match "S-1-5-21"
} | ForEach-Object {

    $explorer = "$($_.PSPath)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"

    if (Test-Path $explorer) {
        Remove-ItemProperty -Path $explorer -Name DisallowRun -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $explorer -Name RestrictRun -ErrorAction SilentlyContinue
        Remove-Item "$explorer\DisallowRun" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$explorer\RestrictRun" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Output "Cleared Explorer restrictions for SID: $($_.PSChildName)"
    }
}

# --------------------------------------------------
# 3. REMOVE MDM FIREWALL RULES (SAFE FILTER)
# --------------------------------------------------
Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
    $_.DisplayName -like "MDM*"
} | Remove-NetFirewallRule

Write-Output "Firewall MDM rules removed"

# --------------------------------------------------
# 4. RE-ENABLE STORE & APP INSTALLER POLICIES
# --------------------------------------------------
reg delete "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /f 2>$null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppInstaller" /f 2>$null

Write-Output "Store policies restored"

# --------------------------------------------------
# 5. FORCE POLICY REFRESH & EXPLORER RESET
# --------------------------------------------------
gpupdate /force | Out-Null

Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Start-Process explorer.exe

Write-Output "Explorer restarted"

# --------------------------------------------------
# FINAL
# --------------------------------------------------
Write-Output "=== UNBLOCK COMPLETE ==="
Write-Output "IMPORTANT: REBOOT THE DEVICE NOW"

shutdown /r /t 5
