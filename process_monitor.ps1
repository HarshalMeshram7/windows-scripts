<#
TOP 20 IMPORTANT PROCESSES SNAPSHOT
- Safe owner resolution
- No red errors
- Sorted by CPU usage
#>

$processes = Get-WmiObject Win32_Process | ForEach-Object {

    try {
        $owner = $_.GetOwner()
        $userName = if ($owner.User) {
            "$($owner.Domain)\$($owner.User)"
        } else {
            "SYSTEM"
        }
    }
    catch {
        $userName = "SYSTEM"
    }

    if ($_.Name -in @("System Idle Process","System")) { return }

    [PSCustomObject]@{
        ProcessName = $_.Name
        PID         = $_.ProcessId
        UserName    = $userName
        CPU         = ($_.KernelModeTime + $_.UserModeTime)
        MemoryMB    = [math]::Round($_.WorkingSetSize / 1MB, 2)
        Path        = $_.ExecutablePath
    }
}

$processes |
    Sort-Object CPU -Descending |
    Select-Object -First 20 |
    ConvertTo-Json -Depth 5




##### This will show top 20 services running