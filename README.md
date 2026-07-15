# ARKAIOS Retro Launcher Wii

Herramientas para convertir una USB/SD de Wii en un entorno unificado de lanzamiento:

- Wii (`wbfs`) mediante USB Loader GX.
- GameCube mediante Nintendont.
- Nintendo 64 mediante Not64.
- Nintendo DS mediante DeSmuME Wii.
- Consolas retro mediante RetroArch Wii.

Panel web:

https://arkaios-retro-wii.djklmr528441.chatgpt.site

## Herramientas incluidas

- `Arkaios_Retro_Launcher_UI.hta`: interfaz local para Windows.
- `Sync-RetroArchWiiMedia.ps1`: escaneo, catalogo, playlists, portadas e instalacion de homebrew faltante.
- `native-wii-launcher/`: base de launcher nativo para compilar a `boot.dol` con devkitPro.
- `index.html`: panel web simple de sincronizacion remota.
- `public/arkaios-wii-manifest.json`: manifest remoto para futuras alineaciones.

## Uso rapido

Abrir:

```bat
Abrir_Arkaios_Retro_Launcher_UI.bat
```

O desde PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Sync-RetroArchWiiMedia.ps1 -WiiRoot D:\ -Scan
powershell -ExecutionPolicy Bypass -File .\Sync-RetroArchWiiMedia.ps1 -WiiRoot D:\ -InstallMissingEmulators
powershell -ExecutionPolicy Bypass -File .\Sync-RetroArchWiiMedia.ps1 -WiiRoot D:\ -CreateCatalog -CreatePlaylists -SyncThumbnails
```

## Politica de descargas

La herramienta descarga emuladores/homebrew desde fuentes publicas de homebrew y portadas desde Libretro.

No descarga ROMs comerciales ni automatiza exploits. El usuario debe aportar sus propios backups legales.

## Fuentes usadas

- Open Shop Channel: Nintendont, Not64, DeSmuME Wii.
- Libretro thumbnails: portadas, snaps y titles.
- devkitPro: toolchain para compilar el launcher nativo Wii.
