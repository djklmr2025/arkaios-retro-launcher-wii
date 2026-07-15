param(
    [string]$WiiRoot = "D:\",
    [string]$ServerUrl = "http://127.0.0.1:8787",
    [string]$DeviceName = "ARKAIOS Wii",
    [switch]$Register,
    [switch]$Heartbeat,
    [switch]$UploadCatalog,
    [switch]$Status
)

$ErrorActionPreference = "Stop"

function Get-DevicePath {
    Join-Path $WiiRoot "retroarch\arkaios\device.json"
}

function Ensure-Device {
    $devicePath = Get-DevicePath
    $deviceDir = Split-Path -Parent $devicePath
    New-Item -ItemType Directory -Force -Path $deviceDir | Out-Null

    if (Test-Path -LiteralPath $devicePath) {
        return Get-Content -Raw -LiteralPath $devicePath | ConvertFrom-Json
    }

    $device = [ordered]@{
        device_id = "arkwii-$([guid]::NewGuid().ToString())"
        name = $DeviceName
        launcher_version = "0.1.0"
        sync_enabled = $true
        created_at = (Get-Date).ToUniversalTime().ToString("o")
        server = $ServerUrl
    }

    $device | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $devicePath -Encoding UTF8
    return Get-Content -Raw -LiteralPath $devicePath | ConvertFrom-Json
}

function Get-LocalIp {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) { return $ip }
    return ""
}

function Get-Catalog {
    $catalogPath = Join-Path $WiiRoot "retroarch\arkaios\catalog.json"
    if (-not (Test-Path -LiteralPath $catalogPath)) {
        return @()
    }
    return Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json
}

function Get-CatalogEntries {
    $raw = @(Get-Catalog)
    $entries = @()

    foreach ($item in $raw) {
        if ($item -is [array]) {
            foreach ($inner in $item) {
                $entries += $inner
            }
        }
        elseif ($item) {
            $entries += $item
        }
    }

    return $entries
}

function Send-Heartbeat {
    $device = Ensure-Device
    $catalog = @(Get-CatalogEntries)
    $systems = @($catalog | Where-Object { $_.PSObject.Properties.Name -contains "System" } | Select-Object -ExpandProperty System -Unique)

    $payload = [ordered]@{
        device_id = $device.device_id
        name = $device.name
        launcher_version = $device.launcher_version
        online = $true
        local_ip = Get-LocalIp
        capabilities = @("heartbeat", "catalog", "save-sync", "covers", "local-rom-import")
        catalog_summary = [ordered]@{
            game_count = $catalog.Count
            systems = $systems
        }
    }

    Invoke-RestMethod -Method Post -Uri "$ServerUrl/api/wii/heartbeat" -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 8)
}

function Send-Catalog {
    $device = Ensure-Device
    $catalog = @(Get-CatalogEntries)
    $payload = [ordered]@{
        device_id = $device.device_id
        items = $catalog
    }
    Invoke-RestMethod -Method Post -Uri "$ServerUrl/api/wii/catalog" -ContentType "application/json" -Body ($payload | ConvertTo-Json -Depth 10)
}

function Show-Status {
    $device = Ensure-Device
    $catalog = @(Get-CatalogEntries)
    [pscustomobject]@{
        DeviceId = $device.device_id
        Name = $device.name
        Server = $ServerUrl
        CatalogItems = $catalog.Count
        DevicePath = Get-DevicePath
    } | Format-List
}

if ($Register) {
    Ensure-Device | ConvertTo-Json -Depth 5
}

if ($Heartbeat) {
    Send-Heartbeat | ConvertTo-Json -Depth 5
}

if ($UploadCatalog) {
    Send-Catalog | ConvertTo-Json -Depth 5
}

if ($Status) {
    Show-Status
}

if (-not ($Register -or $Heartbeat -or $UploadCatalog -or $Status)) {
    Write-Host "Uso:"
    Write-Host "  .\Register-ArkaiosWiiNode.ps1 -Register"
    Write-Host "  .\Register-ArkaiosWiiNode.ps1 -Heartbeat"
    Write-Host "  .\Register-ArkaiosWiiNode.ps1 -UploadCatalog"
    Write-Host "  .\Register-ArkaiosWiiNode.ps1 -Status"
}
