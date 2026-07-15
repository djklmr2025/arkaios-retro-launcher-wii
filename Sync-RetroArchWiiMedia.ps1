param(
    [string]$WiiRoot = "D:\",
    [string]$DevicePrefix = "sd:",
    [switch]$SyncThumbnails,
    [switch]$CreatePlaylists,
    [switch]$CreateCatalog,
    [switch]$ListLegalContent,
    [switch]$ListEmulatorStatus,
    [switch]$InstallMissingEmulators,
    [string]$DownloadLegalContentSystem,
    [string]$DownloadLegalContentName,
    [switch]$Scan,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$thumbnailBaseUrl = "http://thumbnails.libretro.com"
$legalContentBaseUrl = "https://buildbot.libretro.com/assets/cores"

$emulatorPackages = @(
    @{
        Name = "Nintendont"
        AppDir = "Nintendont"
        Url = "https://hbb1.oscwii.org/api/contents/Nintendont/Nintendont.zip"
        RequiredFor = "Nintendo GameCube"
        Source = "Open Shop Channel"
    },
    @{
        Name = "Not64"
        AppDir = "not64"
        Url = "https://hbb1.oscwii.org/api/contents/not64/not64.zip"
        RequiredFor = "Nintendo 64"
        Source = "Open Shop Channel"
    },
    @{
        Name = "DeSmuME Wii"
        AppDir = "DeSmuMEWii"
        Url = "https://hbb1.oscwii.org/api/contents/DeSmuMEWii/DeSmuMEWii.zip"
        RequiredFor = "Nintendo DS"
        Source = "Open Shop Channel"
    }
)

$systems = @(
    @{
        Name = "Nintendo - Super Nintendo Entertainment System"
        Extensions = @(".sfc", ".smc", ".fig", ".swc", ".bs", ".st")
        Cores = @("snes9x_libretro_wii.dol", "snes9x2010_libretro_wii.dol", "snes9x2005_plus_libretro_wii.dol")
    },
    @{
        Name = "Nintendo - Nintendo Entertainment System"
        Extensions = @(".nes", ".fds", ".unf", ".unif")
        Cores = @("fceumm_libretro_wii.dol", "nestopia_libretro_wii.dol", "quicknes_libretro_wii.dol")
    },
    @{
        Name = "Nintendo - Game Boy Advance"
        Extensions = @(".gba")
        Cores = @("mgba_libretro_wii.dol", "gpsp_libretro_wii.dol", "vbam_libretro_wii.dol")
    },
    @{
        Name = "Nintendo - Game Boy Color"
        Extensions = @(".gbc")
        Cores = @("gambatte_libretro_wii.dol", "gearboy_libretro_wii.dol")
    },
    @{
        Name = "Nintendo - Game Boy"
        Extensions = @(".gb")
        Cores = @("gambatte_libretro_wii.dol", "gearboy_libretro_wii.dol")
    },
    @{
        Name = "Sega - Mega Drive - Genesis"
        Extensions = @(".md", ".gen", ".smd", ".bin")
        Cores = @("genesis_plus_gx_libretro_wii.dol", "picodrive_libretro_wii.dol")
    },
    @{
        Name = "Sega - Master System - Mark III"
        Extensions = @(".sms")
        Cores = @("genesis_plus_gx_libretro_wii.dol", "smsplus_libretro_wii.dol")
    },
    @{
        Name = "Sega - Game Gear"
        Extensions = @(".gg")
        Cores = @("genesis_plus_gx_libretro_wii.dol", "gearsystem_libretro_wii.dol")
    },
    @{
        Name = "Atari - 2600"
        Extensions = @(".a26")
        Cores = @("stella2014_libretro_wii.dol")
    },
    @{
        Name = "NEC - PC Engine - TurboGrafx 16"
        Extensions = @(".pce")
        Cores = @("mednafen_pce_fast_libretro_wii.dol")
    }
)

$externalLaunchers = @(
    @{
        Name = "Nintendo - Wii"
        Extensions = @(".wbfs", ".wbf1")
        Roots = @("wbfs")
        Launcher = "USB Loader GX"
        AppPath = "apps\usbloader_gx\boot.dol"
    },
    @{
        Name = "Nintendo - GameCube"
        Extensions = @(".iso", ".gcm", ".ciso")
        Roots = @("games")
        Launcher = "Nintendont"
        AppPath = "apps\Nintendont\boot.dol"
    },
    @{
        Name = "Nintendo - Nintendo 64"
        Extensions = @(".n64", ".z64", ".v64")
        Roots = @("Roms")
        Launcher = "Wii64/Not64"
        AppPath = "apps\not64\boot.dol"
    },
    @{
        Name = "Nintendo - Nintendo DS"
        Extensions = @(".nds")
        Roots = @("Roms")
        Launcher = "DeSmuME Wii"
        AppPath = "apps\DeSmuMEWii\boot.dol"
    }
)

$standaloneRoutes = @(
    @{
        System = "Nintendo - Super Nintendo Entertainment System"
        Launcher = "Snes9x GX"
        AppPath = "apps\snes9xgx\boot.dol"
        RomFolder = "snes9xgx\roms"
        Reason = "Preferido para hacks SNES pesados cuando el core de RetroArch Wii va lento."
    }
)

function Assert-WiiRoot {
    if (-not (Test-Path -LiteralPath $WiiRoot)) {
        throw "No existe WiiRoot: $WiiRoot"
    }
}

function Convert-ToUrlSegment([string]$Value) {
    return [System.Uri]::EscapeDataString($Value).Replace("%2F", "/")
}

function Convert-ToRetroPath([string]$FullName) {
    $root = (Resolve-Path -LiteralPath $WiiRoot).Path.TrimEnd("\")
    $relative = $FullName.Substring($root.Length).TrimStart("\").Replace("\", "/")
    return "$DevicePrefix/$relative"
}

function Get-CorePath($system) {
    foreach ($core in $system.Cores) {
        $candidate = Join-Path $WiiRoot "apps\retroarch-wii\$core"
        if (Test-Path -LiteralPath $candidate) {
            return "$DevicePrefix/apps/retroarch-wii/$core"
        }
    }
    return "DETECT"
}

function Get-RomEntries {
    Assert-WiiRoot

    $romRoot = Join-Path $WiiRoot "Roms"
    if (-not (Test-Path -LiteralPath $romRoot)) {
        throw "No existe carpeta de ROMs: $romRoot"
    }

    $entries = New-Object System.Collections.Generic.List[object]
    $knownExtensions = @{}
    foreach ($system in $systems) {
        foreach ($ext in $system.Extensions) {
            $knownExtensions[$ext.ToLowerInvariant()] = $system
        }
    }

    Get-ChildItem -LiteralPath $romRoot -Recurse -File | ForEach-Object {
        $ext = $_.Extension.ToLowerInvariant()
        if ($knownExtensions.ContainsKey($ext)) {
            $system = $knownExtensions[$ext]
            $entries.Add([pscustomobject]@{
                Path = $_.FullName
                Label = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                System = $system.Name
                CorePath = Get-CorePath $system
                CoreName = "DETECT"
                Source = "file"
            })
        }
        elseif ($ext -eq ".zip") {
            $zipPath = $_.FullName
            $zipEntries = & tar -tf $zipPath 2>$null
            foreach ($zipEntry in $zipEntries) {
                $innerExt = [System.IO.Path]::GetExtension($zipEntry).ToLowerInvariant()
                if ($knownExtensions.ContainsKey($innerExt)) {
                    $system = $knownExtensions[$innerExt]
                    $entries.Add([pscustomobject]@{
                        Path = $zipPath
                        Label = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                        System = $system.Name
                        CorePath = Get-CorePath $system
                        CoreName = "DETECT"
                        Source = "zip"
                    })
                    break
                }
            }
        }
    }

    return $entries | Sort-Object System, Label, Path -Unique
}

function Get-GameIdFromPath([string]$Path) {
    $match = [regex]::Match($Path, "\[([A-Z0-9]{6})\]")
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    $file = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ($file -match "^[A-Z0-9]{6}$") {
        return $file
    }
    return ""
}

function Get-ExternalEntries {
    Assert-WiiRoot

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($launcher in $externalLaunchers) {
        foreach ($rootName in $launcher.Roots) {
            $root = Join-Path $WiiRoot $rootName
            if (-not (Test-Path -LiteralPath $root)) {
                continue
            }

            Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
                $ext = $_.Extension.ToLowerInvariant()
                if ($launcher.Extensions -notcontains $ext) {
                    return
                }

                if ($ext -eq ".wbf1") {
                    return
                }

                $parent = Split-Path -Leaf (Split-Path -Parent $_.FullName)
                $label = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                if ($parent -match "^(.*)\s+\[[A-Z0-9]{6}\]$") {
                    $label = $matches[1]
                }
                elseif ($parent -and $parent -ne $rootName) {
                    $label = $parent
                }

                $appFullPath = Join-Path $WiiRoot $launcher.AppPath
                $entries.Add([pscustomobject]@{
                    Path = $_.FullName
                    Label = $label
                    System = $launcher.Name
                    Launcher = $launcher.Launcher
                    LauncherPath = if (Test-Path -LiteralPath $appFullPath) { Convert-ToRetroPath $appFullPath } else { "MISSING: $($launcher.AppPath)" }
                    GameId = Get-GameIdFromPath $_.FullName
                    Source = "external"
                })
            }
        }
    }

    return $entries | Sort-Object System, Label, Path -Unique
}

function Get-StandaloneRoute($Entry) {
    foreach ($route in $standaloneRoutes) {
        if ($Entry.System -ne $route.System) {
            continue
        }
        $appFullPath = Join-Path $WiiRoot $route.AppPath
        if (Test-Path -LiteralPath $appFullPath) {
            return $route
        }
    }
    return $null
}

function Convert-ToStandaloneRomPath($Entry, $Route) {
    $fileName = [System.IO.Path]::GetFileName($Entry.Path)
    $target = Join-Path (Join-Path $WiiRoot $Route.RomFolder) $fileName
    return $target
}

function Sync-StandaloneRomCopies($Entries) {
    foreach ($entry in $Entries) {
        $route = Get-StandaloneRoute $entry
        if (-not $route) {
            continue
        }
        $target = Convert-ToStandaloneRomPath $entry $route
        if ($WhatIf) {
            Write-Host "WhatIf: copiaria $($entry.Path) -> $target"
            continue
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        if ((-not (Test-Path -LiteralPath $target)) -or ((Get-Item -LiteralPath $target).Length -ne (Get-Item -LiteralPath $entry.Path).Length)) {
            Copy-Item -LiteralPath $entry.Path -Destination $target -Force
            Write-Host "Standalone route: $($entry.Label) -> $target"
        }
    }
}

function Get-AllEntries {
    $retro = @(Get-RomEntries | ForEach-Object {
        $route = Get-StandaloneRoute $_
        if ($route) {
            $appFullPath = Join-Path $WiiRoot $route.AppPath
            $standaloneRomPath = Convert-ToStandaloneRomPath $_ $route
            return [pscustomobject]@{
                Path = $_.Path
                Label = $_.Label
                System = $_.System
                Launcher = $route.Launcher
                LauncherPath = Convert-ToRetroPath $appFullPath
                GameId = ""
                Source = $_.Source
                PreferredLauncher = $route.Launcher
                StandaloneRomPath = Convert-ToRetroPath $standaloneRomPath
                RoutingReason = $route.Reason
            }
        }
        [pscustomobject]@{
            Path = $_.Path
            Label = $_.Label
            System = $_.System
            Launcher = "RetroArch Wii"
            LauncherPath = $_.CorePath
            GameId = ""
            Source = $_.Source
        }
    })
    $external = @(Get-ExternalEntries)
    return @($retro + $external) | Sort-Object System, Label, Path -Unique
}

function New-ThumbnailFolders([string]$SystemName) {
    $base = Join-Path $WiiRoot "retroarch\thumbnails\$SystemName"
    foreach ($folder in @("Named_Boxarts", "Named_Snaps", "Named_Titles")) {
        $target = Join-Path $base $folder
        if (-not $WhatIf) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
        }
    }
}

function Get-ThumbnailCandidates([string]$Label) {
    $short = ($Label -replace "\s*\(.*$", "").Trim()
    return @($Label, $short) | Where-Object { $_ } | Select-Object -Unique
}

function Save-Thumbnail([string]$SystemName, [string]$Label, [string]$Kind) {
    $folder = Join-Path $WiiRoot "retroarch\thumbnails\$SystemName\$Kind"
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
    }

    foreach ($candidate in (Get-ThumbnailCandidates $Label)) {
        $fileName = ($candidate -replace '[&*/:`"<>?\\|]', "_") + ".png"
        $target = Join-Path $folder $fileName
        if (Test-Path -LiteralPath $target) {
            return "exists"
        }

        $url = "$thumbnailBaseUrl/$(Convert-ToUrlSegment $SystemName)/$Kind/$(Convert-ToUrlSegment $fileName)"
        try {
            if ($WhatIf) {
                return "would-check $url"
            }

            Invoke-WebRequest -Uri $url -OutFile $target -TimeoutSec 20 | Out-Null
            if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Length -gt 0)) {
                return "downloaded"
            }
        }
        catch {
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Force
            }
        }
    }

    return "missing"
}

function Sync-Thumbnails {
    $entries = @(Get-RomEntries)
    if ($entries.Count -eq 0) {
        Write-Host "No se encontraron ROMs reales compatibles en $WiiRoot\Roms."
        return
    }

    foreach ($entry in $entries) {
        New-ThumbnailFolders $entry.System
        $box = Save-Thumbnail $entry.System $entry.Label "Named_Boxarts"
        $snap = Save-Thumbnail $entry.System $entry.Label "Named_Snaps"
        $title = Save-Thumbnail $entry.System $entry.Label "Named_Titles"
        [pscustomobject]@{
            System = $entry.System
            Game = $entry.Label
            Boxart = $box
            Snap = $snap
            Title = $title
        }
    }
}

function Show-Scan {
    $entries = @(Get-AllEntries)
    if ($entries.Count -eq 0) {
        Write-Host "No se encontraron juegos compatibles en $WiiRoot."
        return
    }

    $entries | Select-Object System, Label, Launcher, LauncherPath, GameId, Path | Format-Table -AutoSize
}

function Write-Catalog {
    $romEntries = @(Get-RomEntries)
    Sync-StandaloneRomCopies $romEntries
    $entries = @(Get-AllEntries)
    $targetDir = Join-Path $WiiRoot "retroarch\arkaios"
    $target = Join-Path $targetDir "catalog.json"
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        $entries | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $target -Encoding UTF8
    }
    Write-Host "Catalogo creado: $target"
}

function Write-Playlists {
    $entries = @(Get-RomEntries)
    if ($entries.Count -eq 0) {
        Write-Host "No se encontraron ROMs reales compatibles para crear playlists."
        return
    }

    $playlistRoot = Join-Path $WiiRoot "retroarch\playlists"
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path $playlistRoot | Out-Null
    }

    $entries | Group-Object System | ForEach-Object {
        $systemName = $_.Name
        $items = @($_.Group | ForEach-Object {
            [ordered]@{
                path = Convert-ToRetroPath $_.Path
                label = $_.Label
                core_path = $_.CorePath
                core_name = $_.CoreName
                crc32 = "DETECT"
                db_name = "$systemName.lpl"
            }
        })

        $playlist = [ordered]@{
            version = "1.0"
            items = $items
        }

        $target = Join-Path $playlistRoot "$systemName.lpl"
        if ($WhatIf) {
            Write-Host "Se crearia playlist: $target"
        }
        else {
            $playlist | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $target -Encoding UTF8
            Write-Host "Playlist creada: $target"
        }
    }
}

function Get-HrefValues([string]$Html) {
    $matches = [regex]::Matches($Html, 'href="([^"]+)"')
    foreach ($match in $matches) {
        $href = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        if ($href -and $href -ne "../" -and $href -notmatch "^\?") {
            $href
        }
    }
}

function Get-WebText([string]$Url) {
    $text = & curl.exe -L -s $Url
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo descargar indice: $Url"
    }
    return ($text -join "`n")
}

function Get-EmulatorStatus {
    Assert-WiiRoot

    foreach ($pkg in $emulatorPackages) {
        $boot = Join-Path $WiiRoot "apps\$($pkg.AppDir)\boot.dol"
        [pscustomobject]@{
            Name = $pkg.Name
            RequiredFor = $pkg.RequiredFor
            Installed = Test-Path -LiteralPath $boot
            Path = $boot
            Source = $pkg.Source
        }
    }
}

function Install-EmulatorPackage($pkg) {
    $target = Join-Path $WiiRoot "apps\$($pkg.AppDir)"
    $boot = Join-Path $target "boot.dol"
    if (Test-Path -LiteralPath $boot) {
        Write-Host "Ya instalado: $($pkg.Name)"
        return
    }

    $workRoot = Join-Path $env:TEMP "arkaios-wii-emulators"
    $packageRoot = Join-Path $workRoot $pkg.AppDir
    $zipPath = Join-Path $workRoot "$($pkg.AppDir).zip"

    if (-not $WhatIf) {
        if (Test-Path -LiteralPath $packageRoot) {
            Remove-Item -LiteralPath $packageRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    }

    Write-Host "Descargando $($pkg.Name) desde $($pkg.Source)..."
    if ($WhatIf) {
        Write-Host "Se descargaria: $($pkg.Url) -> $zipPath"
        return
    }

    & curl.exe -L -f -o $zipPath $pkg.Url
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo descarga de $($pkg.Name)"
    }

    & tar -xf $zipPath -C $packageRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo extraccion de $($pkg.Name)"
    }

    $extractedBoot = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter "boot.dol" | Select-Object -First 1
    if (-not $extractedBoot) {
        throw "No se encontro boot.dol en paquete $($pkg.Name)"
    }

    Copy-Item -Path (Join-Path $packageRoot "*") -Destination $WiiRoot -Recurse -Force

    if (-not (Test-Path -LiteralPath $boot)) {
        throw "Instalacion incompleta de $($pkg.Name): falta $boot"
    }

    Write-Host "Instalado: $($pkg.Name) -> $target"
}

function Install-MissingEmulators {
    foreach ($pkg in $emulatorPackages) {
        Install-EmulatorPackage $pkg
    }
}

function Resolve-HrefUrl([string]$BaseUrl, [string]$Href) {
    if ($Href -match "^https?://") {
        return $Href
    }
    if ($Href.StartsWith("/")) {
        $baseUri = [uri]$BaseUrl
        return "$($baseUri.Scheme)://$($baseUri.Host)$Href"
    }
    return "$BaseUrl$Href"
}

function Get-HrefLeaf([string]$Href) {
    $clean = $Href.TrimEnd("/")
    $leaf = [System.IO.Path]::GetFileName($clean)
    return [System.Uri]::UnescapeDataString($leaf)
}

function Show-LegalContent {
    $html = Get-WebText "$legalContentBaseUrl/"
    Get-HrefValues $html |
        Where-Object {
            $_.EndsWith("/") -and
            $_ -notmatch "_h5ai|^\?|^\.\./" -and
            ($_ -match "^/assets/cores/[^/]+/$" -or $_ -match "^[^/]+/$")
        } |
        ForEach-Object { Get-HrefLeaf $_ } |
        Where-Object { $_ } |
        Sort-Object
}

function Save-LegalContent {
    if (-not $DownloadLegalContentSystem) {
        throw "Usa -DownloadLegalContentSystem con el nombre exacto del sistema legal/homebrew."
    }

    $systemUrl = "$legalContentBaseUrl/$(Convert-ToUrlSegment $DownloadLegalContentSystem)/"
    $html = Get-WebText $systemUrl
    $files = @(Get-HrefValues $html | Where-Object {
        if ($_.EndsWith("/") -or $_ -match "_h5ai|^\?|^\.\./") {
            return $false
        }
        $leaf = Get-HrefLeaf $_
        return ([System.IO.Path]::GetExtension($leaf).ToLowerInvariant() -in @(".zip", ".7z"))
    })

    if ($DownloadLegalContentName) {
        $files = @($files | Where-Object { $_ -like "*$DownloadLegalContentName*" })
    }

    if ($files.Count -eq 0) {
        Write-Host "No se encontro contenido legal con ese filtro."
        return
    }

    $targetDir = Join-Path $WiiRoot "Roms\Legal Homebrew\$DownloadLegalContentSystem"
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }

    foreach ($file in $files) {
        $url = Resolve-HrefUrl $systemUrl $file
        $target = Join-Path $targetDir (Get-HrefLeaf $file)
        if ($WhatIf) {
            Write-Host "Se descargaria: $url -> $target"
        }
        else {
            Invoke-WebRequest -Uri $url -OutFile $target -TimeoutSec 60 | Out-Null
            Write-Host "Descargado: $target"
        }
    }
}

Assert-WiiRoot

if ($ListLegalContent) {
    Show-LegalContent
}

if ($ListEmulatorStatus) {
    Get-EmulatorStatus | Format-Table -AutoSize
}

if ($InstallMissingEmulators) {
    Install-MissingEmulators
}

if ($Scan) {
    Show-Scan
}

if ($DownloadLegalContentSystem) {
    Save-LegalContent
}

if ($CreatePlaylists) {
    Write-Playlists
}

if ($CreateCatalog) {
    Write-Catalog
}

if ($SyncThumbnails) {
    Sync-Thumbnails | Format-Table -AutoSize
}

if (-not ($ListLegalContent -or $ListEmulatorStatus -or $InstallMissingEmulators -or $DownloadLegalContentSystem -or $CreatePlaylists -or $CreateCatalog -or $SyncThumbnails -or $Scan)) {
    Write-Host "Uso:"
    Write-Host "  .\Sync-RetroArchWiiMedia.ps1 -Scan"
    Write-Host "  .\Sync-RetroArchWiiMedia.ps1 -SyncThumbnails -CreatePlaylists -CreateCatalog"
    Write-Host "  .\Sync-RetroArchWiiMedia.ps1 -ListEmulatorStatus"
    Write-Host "  .\Sync-RetroArchWiiMedia.ps1 -InstallMissingEmulators"
    Write-Host "  .\Sync-RetroArchWiiMedia.ps1 -ListLegalContent"
    Write-Host "  .\Sync-RetroArchWiiMedia.ps1 -DownloadLegalContentSystem 'Cave Story'"
}
