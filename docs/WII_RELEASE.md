# Release Wii SD Pack

Este documento define exactamente que entra en el ZIP de Wii.

## Nombre sugerido

`arkaios-wii-sd-pack-v0.1.0.zip`

## Dependencia real

El sistema de consola depende de `ARKAIOS Retro Launcher Wii`, no de la web ni del servidor.

El launcher detecta y rutea hacia homebrew ya instalado:

- SNES: `apps/snes9xgx/boot.dol`
- Wii: `apps/usbloader_gx/boot.dol`
- GameCube: `apps/nintendont/boot.dol`
- N64: `apps/not64/boot.dol`
- NDS: `apps/DeSmuMEWii/boot.dol`
- Otros retro: RetroArch Wii cores cuando esten disponibles.

Si esos emuladores no existen en la SD/USB, el launcher puede listar juegos pero no lanzarlos correctamente.

## Contenido obligatorio del ZIP

```text
apps/
  arkaios-wii-launcher/
    boot.dol
    meta.xml
retroarch/
  arkaios/
    README.txt
    catalog.json
    metadata.txt
AutoDetectar_Juegos_Wii.bat
```

## Contenido opcional del ZIP

```text
Actualizar_Portadas_RetroArch_Wii.bat
Sync-RetroArchWiiMedia.ps1
Arkaios-SaveSync.ps1
```

## Contenido prohibido en el ZIP publico

```text
Roms/
roms/
wbfs/
games/
*.iso
*.wbfs
*.sfc
*.smc
*.nes
*.n64
*.z64
*.nds
*.gba
*.gb
*.gbc
*.zip con ROMs
data/
node_modules/
.env
secrets/
```

## Despues de copiar el ZIP a una SD/USB

1. Instalar/copiar los emuladores externos necesarios.
2. Copiar backups personales del usuario a `Roms/`, `wbfs/` o `games/`.
3. Ejecutar `AutoDetectar_Juegos_Wii.bat` desde Windows.
4. Expulsar con seguridad.
5. Abrir `ARKAIOS Retro Launcher` desde Homebrew Channel.

## Archivos generados por autodeteccion

```text
retroarch/arkaios/catalog.json
retroarch/arkaios/metadata.txt
retroarch/arkaios/history-latest.txt
retroarch/arkaios/history/history-YYYYMMDD-HHMMSS.txt
retroarch/playlists/*.lpl
```

Estos archivos se pueden sobrescribir en cada escaneo.
