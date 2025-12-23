# Lock the current user's workstation session
# Uses the native Windows command (preferred over P/Invoke for reliability)

rundll32.exe user32.dll,LockWorkStation