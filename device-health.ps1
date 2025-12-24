<#
    Script: device-health.ps1
    Purpose: Collect Windows device health and status and output JSON
    Use case: MDM agent sends this data to backend during checkin
#>

$health = @{}

# CPU Usage
$cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
$health.cpu_usage = [math]::Round($cpuLoad, 2)

# Memory Usage
$mem = Get-CimInstance Win32_OperatingSystem
$totalMem = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
$freeMem  = [math]::Round($mem.FreePhysicalMemory / 1MB, 2)
$usedMem  = [math]::Round(($totalMem - $freeMem), 2)
$memUsage = [math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 2)

$health.memory = @{
    total_gb = $totalMem
    used_gb  = $usedMem
    free_gb  = $freeMem
    usage_percent = $memUsage
}

# Disk Usage
$disks = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    @{
        name = $_.Name
        total_gb = [math]::Round($_.Used/1GB + $_.Free/1GB, 2)
        used_gb  = [math]::Round($_.Used / 1GB, 2)
        free_gb  = [math]::Round($_.Free / 1GB, 2)
        usage_percent = if ($_.Used + $_.Free -eq 0) { 0 } else { [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 2) }
    }
}
$health.disks = $disks

# Battery Status (if available)
try {
    $battery = Get-CimInstance Win32_Battery
    if ($battery) {
        $health.battery = @{
            status = $battery.BatteryStatus
            estimated_charge_remaining_percent = $battery.EstimatedChargeRemaining
        }
    } else {
        $health.battery = "No battery (desktop device)"
    }
} catch {
    $health.battery = "Not available"
}

# Network Info
$netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object Name, MacAddress, LinkSpeed, Status
$health.network = $netAdapters

# Firewall Status
$fwState = (Get-NetFirewallProfile | Select-Object Name, Enabled)
$health.firewall = $fwState

# Antivirus (Windows Defender)
try {
    $defStatus = Get-MpComputerStatus | Select-Object AMServiceEnabled, AntispywareEnabled, AntivirusEnabled, RealTimeProtectionEnabled
    $health.antivirus = $defStatus
} catch {
    $health.antivirus = "Not available"
}

# TPM Status
try {
    $tpm = Get-Tpm
    $health.tpm = @{
        tpm_present = $tpm.TpmPresent
        tpm_ready = $tpm.TpmReady
        tpm_enabled = $tpm.TpmEnabled
    }
} catch {
    $health.tpm = "TPM not supported"
}

# OS Info
$os = Get-CimInstance Win32_OperatingSystem
$health.os = @{
    caption = $os.Caption
    version = $os.Version
    build = $os.BuildNumber
}

# Uptime & Last Boot
$uptime = (Get-Date) - $os.LastBootUpTime
$health.uptime_hours = [math]::Round($uptime.TotalHours, 2)
$health.last_boot = $os.LastBootUpTime

# Pending Reboot
$pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
$health.pending_reboot = $pendingReboot

# Agent Service Status (optional, replace with your agent name)
$agentService = "MyMDMAgent"
try {
    $svc = Get-Service $agentService -ErrorAction Stop
    $health.agent_service = @{
        status = $svc.Status
        startup_type = $svc.StartType
    }
} catch {
    $health.agent_service = "Service not found"
}

# OUTPUT JSON
$health | ConvertTo-Json -Depth 6
