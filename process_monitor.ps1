<#
ONE-TIME PROCESS SNAPSHOT
Returns all currently running processes with:
- Name
- PID
- Username
- CPU usage
- Memory usage
#>

$processes = Get-WmiObject Win32_Process | ForEach-Object {
    $owner = $_.GetOwner()
    [PSCustomObject]@{
        ProcessName = $_.Name
        PID         = $_.ProcessId
        UserName    = "$($owner.Domain)\$($owner.User)"
        CPU         = $_.KernelModeTime + $_.UserModeTime
        MemoryMB    = "{0:N2}" -f ($_.WorkingSetSize / 1MB)
        Path        = $_.ExecutablePath
    }
}

$processes | Sort-Object ProcessName | ConvertTo-Json -Depth 5
