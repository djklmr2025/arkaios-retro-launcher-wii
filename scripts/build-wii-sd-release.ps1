param(
    [string]$Version = "0.1.0",
    [string]$OutDir = "release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$releaseRoot = Join-Path $repoRoot $OutDir
$staging = Join-Path $releaseRoot "arkaios-wii-sd-pack-v$Version"
$zipPath = Join-Path $releaseRoot "arkaios-wii-sd-pack-v$Version.zip"

if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $staging | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $staging "apps\arkaios-wii-launcher") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $staging "retroarch\arkaios") | Out-Null

$dol = Join-Path $repoRoot "native-wii-launcher\arkaios-wii-launcher.dol"
$meta = Join-Path $repoRoot "native-wii-launcher\meta.xml"
if (-not (Test-Path -LiteralPath $dol)) {
    throw "No existe $dol. Compila primero native-wii-launcher."
}
if (-not (Test-Path -LiteralPath $meta)) {
    throw "No existe $meta."
}

Copy-Item -LiteralPath $dol -Destination (Join-Path $staging "apps\arkaios-wii-launcher\boot.dol") -Force
Copy-Item -LiteralPath $meta -Destination (Join-Path $staging "apps\arkaios-wii-launcher\meta.xml") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "AutoDetectar_Juegos_Wii.bat") -Destination $staging -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "Actualizar_Portadas_RetroArch_Wii.bat") -Destination $staging -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "Sync-RetroArchWiiMedia.ps1") -Destination $staging -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "Arkaios-SaveSync.ps1") -Destination $staging -Force

@'
ARKAIOS Retro Launcher Wii

1. Copia este contenido en la raiz de tu SD/USB de Wii.
2. Copia tus backups personales en Roms/, wbfs/ o games/.
3. Ejecuta AutoDetectar_Juegos_Wii.bat desde Windows.
4. Expulsa con seguridad.
5. Abre ARKAIOS Retro Launcher desde Homebrew Channel.

Este pack no incluye ROMs, ISOs, WBFS ni BIOS comerciales.
'@ | Set-Content -LiteralPath (Join-Path $staging "retroarch\arkaios\README.txt") -Encoding ASCII

"[]" | Set-Content -LiteralPath (Join-Path $staging "retroarch\arkaios\catalog.json") -Encoding ASCII
"# key|title|system|launcher|cover" | Set-Content -LiteralPath (Join-Path $staging "retroarch\arkaios\metadata.txt") -Encoding ASCII

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -LiteralPath (Join-Path $staging "*") -DestinationPath $zipPath -Force

Write-Host "Release creado: $zipPath"
Write-Host "Staging: $staging"
