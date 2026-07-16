# Revision Tecnica de WAD Manager v1.7 Mod

Fecha: 2026-07-15

Ruta revisada:

```text
D:\Wad.manager.v1.7.Mod
D:\WAD-Manager_v1.7.dol
```

## Resultado

La carpeta contiene codigo fuente C, binarios DOL/ELF, un WAD de canal y assets. Sirve como referencia tecnica de app Wii nativa, pero no debe usarse como base funcional para instalar canales o juegos dentro de ARKAIOS.

## Partes utiles para ARKAIOS

### Inicializacion segura del sistema

`source/sys.c` registra callbacks reales para RESET y POWER:

```text
SYS_SetResetCallback(...)
SYS_SetPowerCallback(...)
STM_RebootSystem()
STM_ShutdownToIdle()
STM_ShutdownToStandby()
```

Esto conviene llevarlo a ARKAIOS para evitar bloqueos duros cuando una operacion falla.

### Montaje de almacenamiento

`source/fat.c` usa:

```text
dev->interface->startup()
fatMountSimple(...)
chdir("sd:/")
fatUnmount(...)
dev->interface->shutdown()
```

Este patron es mas explicito que el montaje minimo actual. Conviene adoptar una capa parecida para SD/USB.

### Video e imagenes PNG

`source/video.c` usa framebuffer + PNGU:

```text
VIDEO_GetPreferredMode()
SYS_AllocateFramebuffer()
VIDEO_SetNextFramebuffer()
PNGU_DECODE_TO_COORDS_YCbYCr(...)
```

Esto confirma que ARKAIOS puede renderizar covers PNG sin migrar todavia a una UI compleja. Es un buen primer paso para mostrar portadas.

### Mandos

El mod soporta Wiimote y GameCube controller. Para ARKAIOS conviene mantener ambas rutas porque ayuda en pruebas si el Wiimote se desincroniza.

### Configuracion externa

Usa `wm_config.txt` para parametros como IOS, device, startup path, password, musica y disclaimer. ARKAIOS deberia tener un archivo similar:

```text
sd:/retroarch/arkaios/config.txt
```

## Partes que NO se deben copiar

No integrar:

```text
Wad_Install(...)
Wad_Uninstall(...)
NAND emulator install flow
ES/ISFS write flow para WADs
```

Motivo: ARKAIOS no debe convertirse en instalador de contenido WAD ni tocar NAND real desde el launcher general.

## Conclusiones

WAD Manager no resuelve el problema de SNES porque no es un booter de emuladores ni un chainloader de ROMs.

Si ayuda a mejorar ARKAIOS en tres frentes:

1. Robustez del ciclo RESET/POWER.
2. Montaje SD/USB mas limpio.
3. Renderizado de PNG para portadas.

Para el canal ARKAIOS, el camino correcto sigue siendo un forwarder propio que solo abre:

```text
sd:/apps/arkaios-wii-launcher/boot.dol
usb:/apps/arkaios-wii-launcher/boot.dol
```

Para SNES, el camino correcto sigue siendo sustituir el chainloader por un booter compatible tipo WiiFlow `app_booter` o usar integracion plugin/forwarder probada.
