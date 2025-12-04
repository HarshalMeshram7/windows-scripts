<#
    REMOTE LOCK SCRIPT
    - Immediately locks the device
    - Works for any user type (MSA / Local)
#>

# Lock workstation
rundll32.exe user32.dll,LockWorkStation

Write-Output '{"status":"locked"}'
