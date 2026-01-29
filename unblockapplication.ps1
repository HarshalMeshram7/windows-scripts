Write-Output "Reverting Hybrid Application Policy..."

# Remove IFEO blocks
$ifeoRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
)

foreach ($root in $ifeoRoots) {
    Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $dbg = Get-ItemProperty $_.PsPath -Name Debugger -ErrorAction SilentlyContinue
            if ($dbg.Debugger -like "*blocked.exe*") {
                Remove-Item $_.PsPath -Recurse -Force
                Write-Output "Removed execution block: $($_.PSChildName)"
            }
        } catch {}
    }
}

# Remove firewall rules
Get-NetFirewallRule -DisplayName "MDM Hybrid Block*" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

Write-Output "Hybrid policy reverted."
shutdown /r /t 5
