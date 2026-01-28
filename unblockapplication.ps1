Write-Output "=== STARTING FULL EXPLORER RESTRICTION CLEANUP ==="

# --------------------------------------------------
# 1. CLEAN MACHINE-LEVEL POLICIES (CRITICAL)
# --------------------------------------------------
$machineExplorer = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"

if (Test-Path $machineExplorer) {
    Remove-ItemProperty -Path $machineExplorer -Name DisallowRun -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $machineExplorer -Name RestrictRun -ErrorAction SilentlyContinue

    if (Test-Path "$machineExplorer\DisallowRun") {
        Remove-Item "$machineExplorer\DisallowRun" -Recurse -Force
    }
    if (Test-Path "$machineExplorer\RestrictRun") {
        Remove-Item "$machineExplorer\RestrictRun" -Recurse -Force
    }
}

# --------------------------------------------------
# 2. CLEAN ALL USER HIVES (HKU)
# --------------------------------------------------
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

Get-ChildItem HKU:\ | Where-Object {
    $_.Name -match "S-1-5-21"
} | ForEach-Object {

    $explorer = "$($_.PSPath)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"

    if (Test-Path $explorer) {

        Remove-ItemProperty -Path $explorer -Name DisallowRun -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $explorer -Name RestrictRun -ErrorAction SilentlyContinue

        if (Test-Path "$explorer\DisallowRun") {
            Remove-Item "$explorer\DisallowRun" -Recurse -Force
        }
        if (Test-Path "$explorer\RestrictRun") {
            Remove-Item "$explorer\RestrictRun" -Recurse -Force
        }

        Write-Output "Cleaned Explorer policies for SID: $($_.PSChildName)"
    }
}

# --------------------------------------------------
# 3. FORCE GROUP POLICY REFRESH
# --------------------------------------------------
gpupdate /force | Out-Null

# --------------------------------------------------
# 4. HARD RESTART EXPLORER FOR ALL USERS
# --------------------------------------------------
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force

Start-Sleep -Seconds 2
Start-Process explorer.exe

Write-Output "=== CLEANUP COMPLETE ==="
Write-Output "User may need to LOG OFF and LOG BACK IN once."

shutdown /r /t 5