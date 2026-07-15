@echo off
setlocal
cd /d "%~dp0"

set "WIIROOT=D:\"
if not exist "%WIIROOT%apps\" (
  echo No encuentro la SD/USB de Wii en %WIIROOT%.
  set /p WIIROOT="Escribe la unidad raiz de la Wii, ejemplo D:\ : "
)

echo.
echo ARKAIOS Wii AutoDetect
echo Unidad: %WIIROOT%
echo.
echo Escaneando juegos, rutas, metadata, playlists e historial...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-RetroArchWiiMedia.ps1" -WiiRoot "%WIIROOT%" -CreateCatalog -CreatePlaylists

echo.
echo Listo.
echo Metadata: %WIIROOT%retroarch\arkaios\metadata.txt
echo Historial: %WIIROOT%retroarch\arkaios\history-latest.txt
echo Launcher: %WIIROOT%apps\arkaios-wii-launcher\boot.dol
echo.
pause
