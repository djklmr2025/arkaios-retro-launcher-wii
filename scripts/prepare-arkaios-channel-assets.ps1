param(
    [string]$OutputRoot = "release\arkaios-channel-forwarder-assets"
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $repo $OutputRoot
$launcher = Join-Path $repo "native-wii-launcher\arkaios-wii-launcher.dol"
$meta = Join-Path $repo "native-wii-launcher\meta.xml"

if (-not (Test-Path -LiteralPath $launcher)) {
    throw "No existe $launcher. Compila native-wii-launcher primero."
}

Remove-Item -LiteralPath $out -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $out | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $out "payload") | Out-Null

Copy-Item -LiteralPath $launcher -Destination (Join-Path $out "payload\arkaios-wii-launcher.dol") -Force
if (Test-Path -LiteralPath $meta) {
    Copy-Item -LiteralPath $meta -Destination (Join-Path $out "payload\meta.xml") -Force
}

$info = [ordered]@{
    name = "ARKAIOS Retro Launcher Wii"
    title_id_suggested = "AKOS"
    channel_type = "forwarder"
    payload = "payload/arkaios-wii-launcher.dol"
    sd_path = "sd:/apps/arkaios-wii-launcher/boot.dol"
    usb_path = "usb:/apps/arkaios-wii-launcher/boot.dol"
    includes_roms = $false
    includes_wads = $false
    safety = "Test in Dolphin or emuNAND before installing on real NAND. Keep Priiloader or BootMii available."
}

$info | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $out "channel-info.json") -Encoding UTF8

@"
ARKAIOS CHANNEL FORWARDER ASSETS

Este paquete NO es todavia un WAD instalable.

Contenido:
- payload/arkaios-wii-launcher.dol
- payload/meta.xml
- channel-info.json

Objetivo:
Usar estos archivos para construir un canal forwarder propio de ARKAIOS.

No incluir ROMs, WBFS, ISOs, BIOS ni WADs de juegos.

Instalacion en NAND real:
Solo despues de probar el WAD final en un entorno seguro y tener Priiloader/BootMii.
"@ | Set-Content -LiteralPath (Join-Path $out "README.txt") -Encoding UTF8

Get-ChildItem -LiteralPath $out -Recurse -File | Select-Object FullName,Length,LastWriteTime
