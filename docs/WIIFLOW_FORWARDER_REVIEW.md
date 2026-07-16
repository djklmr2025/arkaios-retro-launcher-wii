# Revision de WiiFlow Forwarder

Fecha: 2026-07-15

Repositorio:

```text
https://github.com/wyndchyme/wiiflow-forwarder
C:\ARKAIOS\_research\wii-launcher-bases\wiiflow-forwarder
```

## Hallazgos

El repositorio trae:

```text
forwarder.dol
banner.brlyt
banner_Start.brlan
banner_Loop.brlan
banner/*.png
icon/*.png
LICENSE
```

Licencia:

```text
Apache-2.0
```

El `forwarder.dol` contiene la ruta:

```text
apps/wiiflow/boot.dol
```

Esto confirma que es un forwarder simple: el canal no contiene WiiFlow completo, solo abre el `boot.dol` instalado en SD/USB.

## Relevancia para ARKAIOS

Es una base mas limpia que reutilizar WADs comerciales o canales de juegos.

El equivalente ARKAIOS debe buscar:

```text
apps/arkaios-wii-launcher/boot.dol
```

Con Title ID sugerido:

```text
AKOS
```

## Siguiente paso tecnico

Hay dos rutas viables:

1. Usar CustomizeMii/ForwardMii para construir un WAD nuevo con payload/ruta ARKAIOS.
2. Modificar o recrear un forwarder DOL propio que busque `apps/arkaios-wii-launcher/boot.dol`, y luego empaquetarlo en WAD.

La ruta 1 es mas rapida para una prueba.
La ruta 2 es mejor para un release propio y reproducible.

## Regla de seguridad

No instalar el WAD final en NAND real hasta probarlo primero en Dolphin o tener recuperacion disponible en Wii real.
