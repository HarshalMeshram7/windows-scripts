$nameSpaceName="root\cimv2\mdm\dmmap"
$className="MDM_AssignedAccess"
$obj = Get-CimInstance -Namespace $namespaceName -ClassName $className
Add-Type -AssemblyName System.Web

# --- REPLACE THE ENTIRE CONTENT BETWEEN THE "@" SIGNS WITH YOUR COMPLETE XML ---
$obj.Configuration = [System.Web.HttpUtility]::HtmlEncode(@"
<?xml version="1.0" encoding="utf-8" ?>
<AssignedAccessConfiguration
    xmlns="http://schemas.microsoft.com/AssignedAccess/2017/config"
    xmlns:r1809="http://schemas.microsoft.com/AssignedAccess/201810/config">
    <Profiles>
        <Profile Id="{bc38b341-6836-449d-ad4f-49672ab8e8a2}">
            <AllAppsList>
                <AllowedApps>
                    <!-- Add your apps here. Use r1809:AutoLaunch="true" for the primary app -->
                    <App DesktopAppPath="C:\Program Files (x86)\Internet Explorer\IEXPLORE.EXE" r1809:AutoLaunch="true" />
                    <App DesktopAppPath="C:\Program Files\Internet Explorer\IEXPLORE.EXE" />
                    <App DesktopAppPath="C:\WINDOWS\SYSTEM32\CMD.EXE" />
                    <App DesktopAppPath="C:\Windows\explorer.exe" />
                    <App DesktopAppPath="C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" />
                </AllowedApps>
            </AllAppsList>
            <StartLayout>
                <![CDATA[<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6">
        <start:Group Name="">
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="0" DesktopApplicationID="Microsoft.InternetExplorer.Default"  />
          <start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk" />
        </start:Group>
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>]]>
            </StartLayout>
            <Taskbar ShowTaskbar="true"/>
        </Profile>
    </Profiles>
    <Configs>
        <Config>
            <!-- Change this to your kiosk user account -->
            <Account>temp</Account>
            <!-- This ID must match the Profile Id above -->
            <DefaultProfile Id="{bc38b341-6836-449d-ad4f-49672ab8e8a2}"/>
        </Config>
    </Configs>
</AssignedAccessConfiguration>
"@)
# ------------------------------------------------------------------------------

Set-CimInstance -CimInstance $obj