# Mapa del Proyecto ARKAIOS Retro Launcher Wii

Este repositorio tiene varios frentes. No todos se empaquetan juntos.

## 1. Sistema Wii real

Objetivo: lo que corre en la consola Wii.

Rutas fuente:

- `native-wii-launcher/`: codigo C del launcher nativo.
- `native-wii-launcher/arkaios-wii-launcher.dol`: binario compilado local, ignorado por git.
- `native-wii-launcher/meta.xml`: metadata para Homebrew Channel.

Rutas instaladas en SD/USB:

- `apps/arkaios-wii-launcher/boot.dol`
- `apps/arkaios-wii-launcher/meta.xml`
- `retroarch/arkaios/catalog.json`
- `retroarch/arkaios/metadata.txt`
- `retroarch/arkaios/history-latest.txt`
- `retroarch/arkaios/history/`

No incluye ROMs, WBFS, ISOs ni BIOS comerciales.

## 2. Herramientas PC para SD/USB

Objetivo: escanear la memoria de Wii desde Windows y mantener catalogo, metadata, playlists, portadas e historial.

Archivos principales:

- `AutoDetectar_Juegos_Wii.bat`: boton de autodeteccion.
- `Sync-RetroArchWiiMedia.ps1`: motor de escaneo, catalogo, metadata, playlists, rutas y portadas.
- `Actualizar_Portadas_RetroArch_Wii.bat`: actualiza portadas + metadata.
- `Arkaios-SaveSync.ps1`: sync/backup/restauracion de saves.
- `Arkaios_Retro_Launcher_UI.hta`: UI local Windows.

Estos archivos pueden vivir en el repo y copiarse a la raiz de la SD/USB como comodidad para el usuario de Windows.

## 3. Servidor local / nodo

Objetivo: registrar nodos Wii/PC, recibir heartbeat y catalogos, exponer manifest.

Archivos principales:

- `server/arkaios-node-server.mjs`
- `Register-ArkaiosWiiNode.ps1`
- `server-installer/`
- `protocol/`
- `data/` solo datos locales, ignorados por git.

Este frente no va dentro del ZIP basico de Wii. Es un paquete aparte para PC/NAS.

## 4. MCP / agente

Objetivo: permitir que un agente lea estado, nodos, manifest y catalogos.

Archivos principales:

- `mcp/arkaios-wii-mcp-server.mjs`
- `protocol/arkaios-wii-catalog-item.schema.json`

Este frente depende del servidor local y no va dentro del pack de consola.

## 5. Web / GitHub Pages / Sites

Objetivo: pagina publica, panel, convertidor BPS, sync, nodo y manifest.

Archivos principales:

- `index.html`
- `patcher.js`
- `public/`
- `docs/`
- `scripts/prepare-github-pages.mjs`
- `scripts/prepare-sites-build.mjs`
- `.openai/hosting.json`

Builds:

- `npm run pages`: prepara `docs/` para GitHub Pages.
- `npm run build`: prepara `dist/` para Sites/build local.

No debe contener ROMs comerciales.

## 6. Release ZIP para usuario Wii

El primer release publico debe ser un ZIP de SD/USB con:

- `apps/arkaios-wii-launcher/boot.dol`
- `apps/arkaios-wii-launcher/meta.xml`
- `retroarch/arkaios/README.txt`
- `retroarch/arkaios/catalog.json` vacio o generado localmente
- `retroarch/arkaios/metadata.txt` vacio o generado localmente
- `AutoDetectar_Juegos_Wii.bat`

No debe incluir:

- `Roms/`
- `wbfs/`
- `games/`
- `saves/`, salvo plantillas vacias
- claves, tokens, `data/`, `.env`
- `node_modules/`

## Flujo de trabajo recomendado

Si trabajas en consola Wii:

1. Edita `native-wii-launcher/source/`.
2. Compila con devkitPro.
3. Copia `arkaios-wii-launcher.dol` a `D:\apps\arkaios-wii-launcher\boot.dol`.
4. Prueba en Wii real.

Si trabajas en autodeteccion:

1. Edita `Sync-RetroArchWiiMedia.ps1`.
2. Ejecuta `AutoDetectar_Juegos_Wii.bat` o `-CreateCatalog`.
3. Revisa `D:\retroarch\arkaios\history-latest.txt`.

Si trabajas en web:

1. Edita `index.html`, `patcher.js`, `public/`.
2. Ejecuta `npm run pages`.
3. Verifica `docs/`.

Si trabajas en servidor:

1. Edita `server/`, `protocol/` o `mcp/`.
2. Ejecuta `npm run node-server` o `npm run mcp-server`.
3. No mezcles cambios del servidor con release Wii salvo que sea necesario.
