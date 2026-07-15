# Integracion con Configurable USB Loader

## Decision

ARKAIOS usa Configurable USB Loader como ejecutor preferido para juegos Wii/WBFS.

Motivo:

- Ya existe en la SD como `apps/USBLoader/boot.dol`.
- Ya tiene interfaz grafica, temas, covers 2D/3D/disc/full y lectura WBFS estable.
- Soporta arranque directo por argumento `#GAMEID`.

## Rutas usadas

```text
apps/USBLoader/boot.dol
usb-loader/config.txt
usb-loader/covers/2d/*.png
usb-loader/covers/3d/*.png
usb-loader/covers/disc/*.png
usb-loader/covers/full/*.png
```

## Flujo actual

1. ARKAIOS detecta un `.wbfs`.
2. Extrae el `GAMEID`, por ejemplo `RMCP01`.
3. Lanza `apps/USBLoader/boot.dol`.
4. Pasa el argumento `#RMCP01` para arranque directo.

## Configuracion SD

Si los juegos estan en la misma SD/USB FAT32, `usb-loader/config.txt` debe usar:

```text
device = sd
```

Si se usa un HDD USB real, puede volver a:

```text
device = usb
```

## Retrocompatibilidad

No se modifico todavia el codigo fuente de Configurable USB Loader para mezclar SNES/N64/NDS dentro de su lista.

La ruta recomendada es:

- Wii/WBFS: Configurable USB Loader.
- SNES/N64/NDS/otros: ARKAIOS detecta y lanza el emulador correspondiente.
- Interfaz grafica futura: reutilizar ideas/modulos de `CfgUSBLoader-master` como GRRLIB, PNGU, grid, coverflow y sistema de temas.

Modificar CfgUSBLoader directamente es posible, pero es una fase mayor porque su modelo interno esta centrado en Wii/GameCube/canales y no en ROMs arbitrarios.
