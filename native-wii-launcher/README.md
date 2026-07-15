# ARKAIOS Wii Native Launcher

Objetivo: app nativa para Homebrew Channel que funcione como front-end unico para RetroArch Wii.

Estado actual:

- Escanea `sd:/Roms` y `usb:/Roms`.
- Escanea `sd:/Roms`, `usb:/Roms`, `sd:/wbfs`, `usb:/wbfs`, `sd:/games` y `usb:/games`.
- Detecta plataforma por extension: Wii, GameCube, N64, NDS y varios sistemas RetroArch.
- Muestra una lista basica en pantalla.
- Deja preparado el punto donde se debe integrar el chainloader/arranque del core de RetroArch.

Limitacion honesta:

La maquina actual no tiene devkitPro/devkitPPC instalado, asi que no se genero `boot.dol` todavia. Para compilar hace falta instalar devkitPro y el grupo `wii-dev`. La guia oficial indica que devkitPro usa `pacman` para gestionar toolchains y librerias.

Referencia oficial:

https://devkitpro.org/wiki/Getting_Started

## Compilar

Con devkitPro instalado:

```sh
cd C:/ARKAIOS/wii-retroarch-tools/native-wii-launcher
make
```

Luego copiar:

```text
arkaios-wii-launcher.dol -> D:/apps/arkaios-wii-launcher/boot.dol
meta.xml                 -> D:/apps/arkaios-wii-launcher/meta.xml
icon.png                 -> D:/apps/arkaios-wii-launcher/icon.png
```

## Enfoque tecnico

Para que un juego arranque directo hay dos caminos:

1. Usar RetroArch como front-end real mediante playlists `.lpl`. Esto ya funciona con `Sync-RetroArchWiiMedia.ps1`.
2. Implementar un chainloader nativo que cargue `USB Loader GX`, `Nintendont`, `Not64`, `DeSmuME Wii` o `RetroArch Wii` segun el tipo de juego.

La opcion 2 requiere validar en hardware Wii porque el comportamiento de argumentos/chainload varia por loader y entorno.
