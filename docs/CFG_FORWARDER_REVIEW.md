# Revision de CFG USB Loader Forwarder

Fecha: 2026-07-15

## Material revisado

Repositorio clonado:

```text
C:\ARKAIOS\_research\wii-launcher-bases\CfgUSBLoader-nitraiolo
https://github.com/nitraiolo/CfgUSBLoader
```

WAD local revisado:

```text
D:\WAD\USBLoaderCFG_NForwarder-UCXF-Channel.wad
```

## Hallazgos

El WAD `USBLoaderCFG_NForwarder-UCXF-Channel.wad` parece ser un forwarder, no un juego completo:

```text
tamano: 3,230,592 bytes
Title ID visible por nombre/config: UCXF
tipo WAD header: Is
cert_chain_size: 2560
ticket_size: 676
tmd_size: 592
data_size: 1836480
footer_size: 1390112
```

El README de CFG indica que se puede instalar un channel forwarder para iniciar el loader desde el System Menu. Tambien documenta:

```text
return_to_channel = [0], auto, JODI, FDCL, ...
return_to_channel = UCXF
```

El codigo reconoce UCXF como forwarder de CFG:

```text
55435846 = UCXF
```

## Que significa para ARKAIOS

El forwarder UCXF no carga juegos por si mismo. Su trabajo es abrir el loader instalado en SD/USB.

La arquitectura equivalente para ARKAIOS debe ser:

```text
ARKAIOS Channel AKOS
  -> sd:/apps/arkaios-wii-launcher/boot.dol
  -> usb:/apps/arkaios-wii-launcher/boot.dol
```

Si mas adelante ARKAIOS necesita volver a su canal desde juegos/loaders compatibles, se podria usar:

```text
return_to_channel = AKOS
```

Pero eso depende del loader/emulador y del cIOS/IOS usado. No debe asumirse para Snes9x GX.

## Recomendacion

No reutilizar el WAD UCXF como base publica de ARKAIOS. Usarlo solo como referencia de:

- nombre y funcion de un forwarder real;
- Title ID corto de 4 caracteres;
- patron SD/USB hacia `apps/<app>/boot.dol`;
- `return_to_channel`.

Para ARKAIOS se recomienda generar un forwarder propio con:

```text
Title ID: AKOS
Nombre: ARKAIOS Retro Launcher
Ruta primaria: sd:/apps/arkaios-wii-launcher/boot.dol
Ruta secundaria: usb:/apps/arkaios-wii-launcher/boot.dol
Sin ROMs, WBFS, BIOS ni WADs de juegos.
```
