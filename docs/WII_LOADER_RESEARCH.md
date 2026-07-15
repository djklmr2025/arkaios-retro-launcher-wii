# Investigacion de Launchers Wii

Fecha: 2026-07-15

Este documento separa la investigacion local de launchers Wii del sistema web, servidor MCP y release SD.

## Copia local de la SD

Se dejo una copia ligera de trabajo en:

```text
C:\ARKAIOS\_usb-backups\wii-sd-structure
```

La copia conserva estructura, apps, configuracion, metadata, covers y archivos de soporte. No esta pensada como release publico y no debe subirse completa al repositorio.

La SD real sigue siendo:

```text
D:\
```

## Proyectos clonados para referencia

```text
C:\ARKAIOS\_research\wii-launcher-bases\CfgUSBLoader
C:\ARKAIOS\_research\wii-launcher-bases\WiiFlow_Mod6
C:\ARKAIOS\_research\wii-launcher-bases\postloader
C:\ARKAIOS\_research\wii-launcher-bases\custom-di-neek2o
```

## Hallazgos

### Configurable USB Loader

Es la mejor base practica para juegos Wii/WBFS en esta SD.

- Ya existe en `D:\apps\USBLoader\boot.dol`.
- Ya maneja cIOS, FAT/WBFS/NTFS, covers 2D/3D/disc/full y themes.
- Soporta arranque directo por argumento `#GAMEID`.
- La config actual debe mantenerse con `device = sd` si los juegos estan en la SD.

Uso recomendado en ARKAIOS:

```text
Wii/WBFS -> apps/USBLoader/boot.dol #GAMEID
```

### WiiFlow Mod

Es la mejor referencia para una interfaz futura con coverflow y ROMs de varias consolas.

- Tiene sistema de plugins para emuladores.
- Usa `source_menu.ini` para separar plataformas.
- Maneja covers de plugin en `wiiflow/covers/[folder]` y `wiiflow/boxcovers/[folder]`.
- Integra GameTDB para Wii/GameCube/canales.
- Tiene rutas y cache para portadas y metadata.

Uso recomendado:

- Tomar su modelo de `plugins`, `source menu`, covers y cache como diseno de segunda etapa.
- No reemplazar de inmediato el launcher actual hasta tener una prueba minima grafica estable.

### postLoader

Es util como referencia para NAND emulada y neek2o.

- Tiene navegador de homebrew con plugins.
- Tiene integracion con UNEEK/neek2o y cambio de NAND.
- Puede delegar a CFG, GX o WiiFlow.

Uso recomendado:

- Referencia para una fase avanzada de emuNAND.
- No usar como base inmediata para el primer launcher universal.

### custom-di-neek2o

Es codigo de bajo nivel para neek2o/SNEEK/UNEEK.

- Genera kernels como `kernel.bin`, `di.bin` y variantes boot2.
- Toca IOS, DI y almacenamiento USB a bajo nivel.

Uso recomendado:

- Solo referencia tecnica.
- No conviene integrarlo hasta que el launcher basico y la ruta Wii/SNES funcionen bien.

## Camino recomendado

1. Mantener ARKAIOS como autodetector y orquestador.
2. Lanzar Wii/WBFS por Configurable USB Loader.
3. Lanzar SNES/N64/NDS/GameCube por emuladores dedicados ya instalados.
4. Mejorar primero el handoff de SNES porque Snes9x GX abre, pero puede quedarse esperando si no recibe argumentos como espera.
5. Agregar render PNG con GRRLIB/PNGU o migrar la UI a una base tipo WiiFlow cuando el lanzamiento sea estable.
6. Despues conectar servidor/MCP para catalogo, covers y saves. Esa etapa no debe bloquear que el launcher local funcione.

## Limites del release publico

No incluir en el repositorio ni en ZIP publico:

```text
Roms/
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
*.zip con ROMs
```

El release publico debe incluir launcher, scripts, metadata vacia o generada localmente, y documentacion.
