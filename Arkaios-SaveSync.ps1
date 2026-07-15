param(
    [string]$WiiRoot = "D:\",
    [string]$SyncRoot = "C:\ARKAIOS\arkaios-wii-sync",
    [string]$ImportPath,
    [switch]$Status,
    [switch]$BackupSaves,
    [switch]$SyncSaves,
    [switch]$RestoreSaves,
    [switch]$ImportRom,
    [switch]$RebuildAfterImport,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$romSystems = @(
    @{ Name = "Nintendo - Super Nintendo Entertainment System"; Extensions = @(".sfc", ".smc", ".fig", ".swc", ".bs", ".st") },
    @{ Name = "Nintendo - Nintendo Entertainment System"; Extensions = @(".nes", ".fds", ".unf", ".unif") },
    @{ Name = "Nintendo - Game Boy Advance"; Extensions = @(".gba") },
    @{ Name = "Nintendo - Game Boy Color"; Extensions = @(".gbc") },
    @{ Name = "Nintendo - Game Boy"; Extensions = @(".gb") },
    @{ Name = "Nintendo - Nintendo 64"; Extensions = @(".n64", ".z64", ".v64") },
    @{ Name = "Nintendo - Nintendo DS"; Extensions = @(".nds") },
    @{ Name = "Sega - Mega Drive - Genesis"; Extensions = @(".md", ".gen", ".smd", ".bin") },
    @{ Name = "Sega - Master System - Mark III"; Extensions = @(".sms") },
    @{ Name = "Sega - Game Gear"; Extensions = @(".gg") },
    @{ Name = "Atari - 2600"; Extensions = @(".a26") },
    @{ Name = "NEC - PC Engine - TurboGrafx 16"; Extensions = @(".pce") }
)

$saveSources = @(
    @{ Name = "RetroArch saves"; Relative = "retroarch\saves" },
    @{ Name = "RetroArch states"; Relative = "retroarch\states" },
    @{ Name = "RetroArch arkaios"; Relative = "retroarch\arkaios" },
    @{ Name = "SNES local saves"; Relative = "Roms\Nintendo - Super Nintendo Entertainment System\_saves" }
)

function Assert-WiiRoot {
    if (-not (Test-Path -LiteralPath $WiiRoot)) {
        throw "No existe WiiRoot: $WiiRoot"
    }
}

function Get-SyncMirrorPath([string]$Relative) {
    Join-Path $SyncRoot $Relative
}

function Ensure-Directory([string]$Path) {
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Copy-NewerTree([string]$From, [string]$To) {
    if (-not (Test-Path -LiteralPath $From)) {
        return 0
    }

    Ensure-Directory $To
    $copied = 0
    Get-ChildItem -LiteralPath $From -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring((Resolve-Path -LiteralPath $From).Path.Length).TrimStart("\")
        $target = Join-Path $To $relative
        $targetDir = Split-Path -Parent $target
        $shouldCopy = -not (Test-Path -LiteralPath $target)

        if (-not $shouldCopy) {
            $targetItem = Get-Item -LiteralPath $target
            $shouldCopy = $_.LastWriteTimeUtc -gt $targetItem.LastWriteTimeUtc -or $_.Length -ne $targetItem.Length
        }

        if ($shouldCopy) {
            if (-not $WhatIf) {
                New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $target -Force
            }
            $script:copied++
        }
    }

    return $copied
}

function Show-Status {
    Assert-WiiRoot
    Ensure-Directory $SyncRoot

    $saveSources | ForEach-Object {
        $source = Join-Path $WiiRoot $_.Relative
        $mirror = Get-SyncMirrorPath $_.Relative
        $sourceCount = if (Test-Path -LiteralPath $source) { @(Get-ChildItem -LiteralPath $source -Recurse -File).Count } else { 0 }
        $mirrorCount = if (Test-Path -LiteralPath $mirror) { @(Get-ChildItem -LiteralPath $mirror -Recurse -File).Count } else { 0 }
        [pscustomobject]@{
            Name = $_.Name
            WiiPath = $source
            SyncPath = $mirror
            WiiFiles = $sourceCount
            SyncFiles = $mirrorCount
        }
    }
}

function Backup-Saves {
    Assert-WiiRoot
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupRoot = Join-Path $SyncRoot "backups\$stamp"
    Ensure-Directory $backupRoot

    foreach ($sourceDef in $saveSources) {
        $source = Join-Path $WiiRoot $sourceDef.Relative
        $target = Join-Path $backupRoot $sourceDef.Relative
        $script:copied = 0
        Copy-NewerTree $source $target | Out-Null
        Write-Host "Backup $($sourceDef.Name): $script:copied archivo(s) -> $target"
    }
}

function Sync-SavesBidirectional {
    Assert-WiiRoot
    Ensure-Directory $SyncRoot

    foreach ($sourceDef in $saveSources) {
        $wiiPath = Join-Path $WiiRoot $sourceDef.Relative
        $syncPath = Get-SyncMirrorPath $sourceDef.Relative
        Ensure-Directory $wiiPath
        Ensure-Directory $syncPath

        $script:copied = 0
        Copy-NewerTree $wiiPath $syncPath | Out-Null
        $toSync = $script:copied

        $script:copied = 0
        Copy-NewerTree $syncPath $wiiPath | Out-Null
        $toWii = $script:copied

        Write-Host "Sync $($sourceDef.Name): Wii->Sync $toSync, Sync->Wii $toWii"
    }
}

function Restore-SavesFromLatestBackup {
    Assert-WiiRoot
    $backupRoot = Join-Path $SyncRoot "backups"
    if (-not (Test-Path -LiteralPath $backupRoot)) {
        throw "No hay backups en $backupRoot"
    }

    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw "No hay backups disponibles en $backupRoot"
    }

    foreach ($sourceDef in $saveSources) {
        $source = Join-Path $latest.FullName $sourceDef.Relative
        $target = Join-Path $WiiRoot $sourceDef.Relative
        $script:copied = 0
        Copy-NewerTree $source $target | Out-Null
        Write-Host "Restore $($sourceDef.Name): $script:copied archivo(s) -> $target"
    }
}

function Get-RomSystem([string]$FilePath) {
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    foreach ($system in $romSystems) {
        if ($system.Extensions -contains $ext) {
            return $system
        }
    }
    return $null
}

function Import-RomFile {
    Assert-WiiRoot
    if (-not $ImportPath) {
        throw "Usa -ImportPath con la ruta del ROM local."
    }
    if (-not (Test-Path -LiteralPath $ImportPath)) {
        throw "No existe ImportPath: $ImportPath"
    }

    $item = Get-Item -LiteralPath $ImportPath
    if ($item.PSIsContainer) {
        throw "ImportPath debe ser un archivo ROM, no una carpeta."
    }

    $system = Get-RomSystem $item.FullName
    if (-not $system) {
        throw "Extension no soportada para importacion: $($item.Extension)"
    }

    $targetDir = Join-Path $WiiRoot "Roms\$($system.Name)"
    $target = Join-Path $targetDir $item.Name

    Ensure-Directory $targetDir
    if (-not $WhatIf) {
        Copy-Item -LiteralPath $item.FullName -Destination $target -Force
    }

    Write-Host "ROM importada: $target"

    if ($RebuildAfterImport) {
        $syncScript = Join-Path $PSScriptRoot "Sync-RetroArchWiiMedia.ps1"
        if (Test-Path -LiteralPath $syncScript) {
            if ($WhatIf) {
                & powershell -NoProfile -ExecutionPolicy Bypass -File $syncScript -WiiRoot $WiiRoot -CreateCatalog -CreatePlaylists -SyncThumbnails -WhatIf
            }
            else {
                & powershell -NoProfile -ExecutionPolicy Bypass -File $syncScript -WiiRoot $WiiRoot -CreateCatalog -CreatePlaylists -SyncThumbnails
            }
        }
    }
}

if ($Status) {
    Show-Status | Format-Table -AutoSize
}

if ($BackupSaves) {
    Backup-Saves
}

if ($SyncSaves) {
    Sync-SavesBidirectional
}

if ($RestoreSaves) {
    Restore-SavesFromLatestBackup
}

if ($ImportRom) {
    Import-RomFile
}

if (-not ($Status -or $BackupSaves -or $SyncSaves -or $RestoreSaves -or $ImportRom)) {
    Write-Host "Uso:"
    Write-Host "  .\Arkaios-SaveSync.ps1 -Status"
    Write-Host "  .\Arkaios-SaveSync.ps1 -BackupSaves"
    Write-Host "  .\Arkaios-SaveSync.ps1 -SyncSaves"
    Write-Host "  .\Arkaios-SaveSync.ps1 -RestoreSaves"
    Write-Host "  .\Arkaios-SaveSync.ps1 -ImportRom -ImportPath C:\ruta\juego.sfc -RebuildAfterImport"
}
