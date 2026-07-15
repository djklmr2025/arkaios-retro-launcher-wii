# ARKAIOS Retro Launcher Wii

Herramientas para convertir una USB/SD de Wii en un entorno unificado de lanzamiento:

- Wii (`wbfs`) mediante USB Loader GX.
- GameCube mediante Nintendont.
- Nintendo 64 mediante Not64.
- Nintendo DS mediante DeSmuME Wii.
- Consolas retro mediante RetroArch Wii.

Panel web:

https://djklmr2025.github.io/arkaios-retro-launcher-wii/

Panel Sites privado/owner-only:

https://arkaios-retro-wii.djklmr528441.chatgpt.site

## Herramientas incluidas

- `Arkaios_Retro_Launcher_UI.hta`: interfaz local para Windows.
- `Sync-RetroArchWiiMedia.ps1`: escaneo, catalogo, playlists, portadas e instalacion de homebrew faltante.
- `Arkaios-SaveSync.ps1`: backup/sync/restauracion de saves e importacion local de ROMs.
- `Register-ArkaiosWiiNode.ps1`: registro anonimo, heartbeat y subida de catalogo.
- `server/arkaios-node-server.mjs`: API local para nodos ARKAIOS Wii.
- `protocol/arkaios-wii-node.schema.json`: contrato del nodo.
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
powershell -ExecutionPolicy Bypass -File .\Arkaios-SaveSync.ps1 -WiiRoot D:\ -SyncSaves
npm run node-server
powershell -ExecutionPolicy Bypass -File .\Register-ArkaiosWiiNode.ps1 -WiiRoot D:\ -Register
powershell -ExecutionPolicy Bypass -File .\Register-ArkaiosWiiNode.ps1 -WiiRoot D:\ -Heartbeat
powershell -ExecutionPolicy Bypass -File .\Register-ArkaiosWiiNode.ps1 -WiiRoot D:\ -UploadCatalog
```

## Save sync

La sincronizacion local usa por defecto:

```text
C:\ARKAIOS\arkaios-wii-sync
```

Rutas incluidas:

- `D:\retroarch\saves`
- `D:\retroarch\states`
- `D:\retroarch\arkaios`
- `D:\Roms\Nintendo - Super Nintendo Entertainment System\_saves`

El flujo es conservador: copia archivos nuevos o mas recientes entre USB y mirror local. Antes de restaurar se recomienda ejecutar `-BackupSaves`.

## ARKAIOS Wii Node

El modo nodo usa un `device_id` anonimo guardado en:

```text
D:\retroarch\arkaios\device.json
```

No usa MAC real como identificador publico. El servidor local acepta:

- `GET /health`
- `POST /api/wii/heartbeat`
- `POST /api/wii/catalog`
- `GET /api/wii/nodes`
- `GET /api/wii/manifest`

La API almacena metadatos y catalogos, no ROMs comerciales.

## Politica de descargas

La herramienta descarga emuladores/homebrew desde fuentes publicas de homebrew y portadas desde Libretro.

No descarga ROMs comerciales ni automatiza exploits. El usuario debe aportar sus propios backups legales.

## Fuentes usadas

- Open Shop Channel: Nintendont, Not64, DeSmuME Wii.
- Libretro thumbnails: portadas, snaps y titles.
- devkitPro: toolchain para compilar el launcher nativo Wii.
