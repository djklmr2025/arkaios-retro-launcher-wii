# Canal WAD ARKAIOS

Objetivo: crear un canal instalable que aparezca en el Menu Wii y abra ARKAIOS Retro Launcher sin entrar primero al Homebrew Channel.

## Estado actual

Es posible crear el canal, pero no se debe instalar un WAD en NAND real hasta probarlo de forma controlada.

El payload correcto para el canal es:

```text
native-wii-launcher/arkaios-wii-launcher.dol
```

Ese DOL ya lee:

```text
sd:/apps/arkaios-wii-launcher/
usb:/apps/arkaios-wii-launcher/
sd:/Roms/
usb:/Roms/
sd:/wbfs/
usb:/wbfs/
```

## Regla de seguridad

No usar WADs comerciales, Virtual Console injects ni canales de terceros como base del canal ARKAIOS.

No instalar en NAND real hasta tener:

- BootMii o Priiloader funcional.
- Una prueba previa en Dolphin o emuNAND cuando sea posible.
- Un WAD forwarder pequeño y propio.

## Diseno recomendado

Canal:

```text
Nombre visible: ARKAIOS
Title ID sugerido: AKOS
Tipo: Forwarder / Homebrew Channel
Payload: arkaios-wii-launcher.dol
Ruta esperada:
  sd:/apps/arkaios-wii-launcher/boot.dol
  usb:/apps/arkaios-wii-launcher/boot.dol
```

El canal no debe contener ROMs, WBFS, BIOS, saves ni WADs de juegos.

## Flujo de construccion

1. Compilar `native-wii-launcher/arkaios-wii-launcher.dol`.
2. Preparar assets del canal.
3. Empaquetar un WAD forwarder propio con herramienta de empaquetado WAD confiable.
4. Probar en Dolphin/emuNAND si es posible.
5. Instalar en Wii real solo si hay recuperacion disponible.

## Diferencia contra WADs de juegos

Los WADs de juegos como Virtual Console o injects suelen traer contenido de juego dentro del canal. ARKAIOS no debe hacer eso.

ARKAIOS debe ser solo un lanzador:

```text
Canal ARKAIOS -> ARKAIOS boot.dol -> SD/USB -> emulador/loader correcto
```

## Estado SNES

SNES sigue en modo seguro. ARKAIOS prepara el juego seleccionado para Snes9x GX, pero no hace chainload directo hasta integrar un booter compatible.
