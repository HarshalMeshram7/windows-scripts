param(
    [string]$AppName = "google chrome",
    [string]$PolicyPath = "C:\ProgramData\MyMDM\PublisherBlock.xml"
)

# Ensure directory exists
New-Item -Path "C:\ProgramData\MyMDM" -ItemType Directory -Force | Out-Null

Write-Host "Searching for installed app matching: $AppName"

# 1. Find signed EXE by product name
$searchPaths = @(
    "C:\Program Files",
    "C:\Program Files (x86)",
    "D:\Program Files",
    "D:\Program Files (x86)",
    "E:\Program Files",
    "E:\Program Files (x86)"
)

$appFile = $null

foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {

        $exeFiles = Get-ChildItem -Path $basePath -Recurse -Filter *.exe -ErrorAction SilentlyContinue

        foreach ($file in $exeFiles) {
            try {
                $info = Get-AppLockerFileInformation -Path $file.FullName -ErrorAction SilentlyContinue
                if ($info.Publisher -and
                    $info.Publisher.ProductName -and
                    $info.Publisher.ProductName.ToLower().Contains($AppName.ToLower())) {

                    $appFile = $file.FullName
                    break
                }
            } catch {}
        }
    }

    if ($appFile) { break }
}

if (-not $appFile) {
    Write-Host "No signed app found matching name: $AppName"
    exit
}

Write-Host "Matched executable: $appFile"

# 2. Extract publisher info
$fileInfo = Get-AppLockerFileInformation -Path $appFile

$publisherName = $fileInfo.Publisher.PublisherName
$productName   = $fileInfo.Publisher.ProductName
$binaryName    = $fileInfo.Publisher.BinaryName

Write-Host "PublisherName: $publisherName"
Write-Host "ProductName:   $productName"
Write-Host "BinaryName:    $binaryName"

# 3. Generate valid GUID
$guid = [guid]::NewGuid().ToString()

# 4. Build XML via .NET (no invalid root issues)
[xml]$xml = New-Object System.Xml.XmlDocument

$root = $xml.CreateElement("AppLockerPolicy")
$root.SetAttribute("Version", "1")
$xml.AppendChild($root) | Out-Null

$ruleCollection = $xml.CreateElement("RuleCollection")
$ruleCollection.SetAttribute("Type", "Exe")
$ruleCollection.SetAttribute("EnforcementMode", "Enabled")
$root.AppendChild($ruleCollection) | Out-Null

$rule = $xml.CreateElement("FilePublisherRule")
$rule.SetAttribute("Id", $guid)
$rule.SetAttribute("Name", "Block $productName")
$rule.SetAttribute("Description", "Block app by publisher")
$rule.SetAttribute("UserOrGroupSid", "S-1-1-0")
$rule.SetAttribute("Action", "Deny")
$ruleCollection.AppendChild($rule) | Out-Null

$conditions = $xml.CreateElement("Conditions")
$rule.AppendChild($conditions) | Out-Null

$condition = $xml.CreateElement("FilePublisherCondition")
$condition.SetAttribute("PublisherName", $publisherName)
$condition.SetAttribute("ProductName",   $productName)
$condition.SetAttribute("BinaryName",    $binaryName)
$conditions.AppendChild($condition) | Out-Null

$versionRange = $xml.CreateElement("BinaryVersionRange")
$versionRange.SetAttribute("LowSection",  "0.0.0.0")
$versionRange.SetAttribute("HighSection", "*")
$condition.AppendChild($versionRange) | Out-Null

# 5. Save clean XML
$xml.Save($PolicyPath)

# 6. Apply policy
Set-AppLockerPolicy -XMLPolicy $PolicyPath -Merge:$true

Write-Host "Successfully blocked app by name: $productName"
