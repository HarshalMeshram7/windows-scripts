<#
GET DEVICE LOCATION (Network-Based Geolocation)
Uses public IP to determine city/state/country/lat/lon
#>

try {
    # Step 1: Get Public IP
    $ip = Invoke-RestMethod -Uri "https://api.ipify.org?format=json"
    $publicIP = $ip.ip

    # Step 2: Get Geolocation from IP
    $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/$publicIP"

    $result = [PSCustomObject]@{
        Status      = "Success"
        IPAddress   = $publicIP
        Country     = $geo.country
        Region      = $geo.regionName
        City        = $geo.city
        ZIP         = $geo.zip
        Latitude    = $geo.lat
        Longitude   = $geo.lon
        ISP         = $geo.isp
        Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }

    $result | ConvertTo-Json -Depth 5
}
catch {
    Write-Output '{"status":"failed","error":"location_fetch_error"}'
}
