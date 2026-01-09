# ==========================================
# Force Lock Device from MDM (SYSTEM safe)
# ==========================================

$TaskName = "MDM_ForceLock"

try {
    # Check active user
    $session = query user 2>$null | Select-Object -Skip 1 | Select-Object -First 1
    if (-not $session) {
        Write-Output "No active user session found."
        exit 0
    }

    Write-Output "Active user session detected."

    # Delete task if exists
    schtasks /delete /tn $TaskName /f 2>$null | Out-Null

    # Create task (INTERACTIVE user context)
    schtasks /create `
        /tn $TaskName `
        /tr "rundll32.exe user32.dll,LockWorkStation" `
        /sc ONCE `
        /st 00:00 `
        /ru "INTERACTIVE" `
        /rl HIGHEST `
        /f | Out-Null

    Write-Output "Scheduled task created."

    # Run task immediately
    schtasks /run /tn $TaskName | Out-Null
    Write-Output "Lock command executed."

    # Cleanup
    Start-Sleep -Seconds 5
    schtasks /delete /tn $TaskName /f | Out-Null
    Write-Output "Cleanup completed."

}
catch {
    Write-Output "ERROR: $_"
    exit 1
}
