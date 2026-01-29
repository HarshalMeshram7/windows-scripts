Write-Output "=== FIXING CHROME EXECUTION ==="

$chromeIfeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\chrome.exe"

if (Test-Path $chromeIfeo) {
    Remove-Item -Path $chromeIfeo -Recurse -Force
    Write-Output "Removed IFEO key for chrome.exe"
} else {
    Write-Output "No IFEO key found for chrome.exe"
}

# Also check WOW6432Node (safety)
$chromeIfeoWow = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\chrome.exe"

if (Test-Path $chromeIfeoWow) {
    Remove-Item -Path $chromeIfeoWow -Recurse -Force
    Write-Output "Removed IFEO key for chrome.exe (WOW6432Node)"
}

# Flush Explorer & shell cache
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe

Write-Output "=== CHROME FIX APPLIED ==="
Write-Output "IMPORTANT: REBOOT REQUIRED"


shutdown /r /t 5