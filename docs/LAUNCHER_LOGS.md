# Logs del Launcher Wii

ARKAIOS Retro Launcher Wii escribe logs en la SD/USB para diagnosticar errores sin depender de fotos de pantalla.

## Archivos

```text
sd:/retroarch/arkaios/launcher.log
sd:/retroarch/arkaios/launcher-latest.log
```

Si SD no esta disponible, intenta:

```text
usb:/retroarch/arkaios/launcher.log
usb:/retroarch/arkaios/launcher-latest.log
```

## Diferencia

- `launcher.log`: historial acumulado.
- `launcher-latest.log`: solo la sesion mas reciente; se reinicia cada vez que abre ARKAIOS.

## Que registra

- Estado de montaje SD/USB.
- Cantidad de metadata cargada.
- Cantidad de juegos detectados.
- Juego seleccionado.
- App/launcher elegido.
- Ruta del DOL resuelta.
- GAMEID para Configurable USB Loader.
- Estado de safe mode SNES.
- Errores de lectura, DOL invalido, argumentos o chainload.

## Uso recomendado

1. Abrir ARKAIOS en Wii.
2. Intentar lanzar el juego que falla.
3. Presionar `B` para volver si aparece error.
4. Apagar o salir.
5. Conectar SD/USB al PC.
6. Leer `retroarch/arkaios/launcher-latest.log`.
