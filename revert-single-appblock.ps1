param(
    [string]$ProductName = "GOOGLE CHROME", 
    [string]$PolicyPath = "C:\ProgramData\MyMDM\PublisherBlock.xml"
)

# Load existing policy
if (-not (Test-Path $PolicyPath)) {
    Write-Host "No publisher block policy found. Nothing to revert."
    exit
}

[xml]$xml = Get-Content $PolicyPath

# Find the RuleCollection for EXE rules
$rules = $xml.AppLockerPolicy.RuleCollection.FilePublisherRule

if ($rules -eq $null) {
    Write-Host "No publisher rules found."
    exit
}

# Find matching rules
$matched = @()
foreach ($rule in $rules) {

    $condition = $rule.SelectSingleNode("Conditions/FilePublisherCondition")
    if ($condition -and $condition.ProductName -eq $ProductName) {
        $matched += $rule
    }
}

if ($matched.Count -eq 0) {
    Write-Host "No block rule found for product: $ProductName"
    exit
}

# Remove matched rules
foreach ($rule in $matched) {
    $null = $rule.ParentNode.RemoveChild($rule)
}

# Save updated policy
$xml.Save($PolicyPath)

# Re-apply cleaned policy
Set-AppLockerPolicy -XMLPolicy $PolicyPath -Merge:$false

Write-Host "Reverted AppLocker publisher rule for product: $ProductName"
