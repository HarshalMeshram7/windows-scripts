reg delete "HKLM\Software\Policies\Microsoft\Windows\Installer" /f
reg delete "HKLM\Software\Policies\Microsoft\Windows\SrpV2" /f
reg delete "HKLM\Software\Policies\Microsoft\Windows\Safer" /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies" /f
sc.exe stop AppIDSvc
gpupdate /force
