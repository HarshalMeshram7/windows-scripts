Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Lock {
    [DllImport("user32.dll")]
    public static extern void LockWorkStation();
}
"@
[Lock]::LockWorkStation()
