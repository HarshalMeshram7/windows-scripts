if (-not ("Win32" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(
        IntPtr hWnd,
        out uint processId
    );
}
"@
}

$usage = @{}
$lastApp = $null
$lastTime = Get-Date

$trackingMinutes = 10
$endTime = (Get-Date).AddMinutes($trackingMinutes)

Write-Host "Tracking app usage for $trackingMinutes minutes..."

while ((Get-Date) -lt $endTime) {
    $hwnd = [Win32]::GetForegroundWindow()

    $processId = 0
    [void][Win32]::GetWindowThreadProcessId($hwnd, [ref]$processId)

    try {
        $process = Get-Process -Id $processId -ErrorAction Stop
        $currentApp = $process.ProcessName
    } catch {
        Start-Sleep -Seconds 1
        continue
    }

    $now = Get-Date

    if ($lastApp) {
        $elapsed = ($now - $lastTime).TotalSeconds
        $usage[$lastApp] = ($usage[$lastApp] + $elapsed)
    }

    $lastApp = $currentApp
    $lastTime = $now

    Start-Sleep -Seconds 1
}

$result = $usage.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        Application = $_.Key
        TimeMinutes = [math]::Round($_.Value / 60, 2)
    }
}

$outputPath = "$env:USERPROFILE\AppUsage.csv"
$result |
    Sort-Object TimeMinutes -Descending |
    Export-Csv -NoTypeInformation $outputPath

Write-Host "App usage data saved to $outputPath"
