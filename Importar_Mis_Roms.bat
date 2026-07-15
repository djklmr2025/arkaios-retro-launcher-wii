@echo off
cd /d "%~dp0"
set /p ROMDIR="Escribe la ruta de la carpeta con TUS ROMs propias (ej. D:\Roms): "
set /p DEVID="Escribe el ID de tu Wii (ej. arkwii-mi-wii-01): "

echo.
echo Escaneando %ROMDIR% ...
node server\local-importer.mjs --dir "%ROMDIR%" --device "%DEVID%" --out data\catalog-local.json

echo.
echo Catalogo guardado en data\catalog-local.json
echo.
choice /M "Quieres subirlo ahora al servidor local ARKAIOS"
if errorlevel 2 goto end

echo.
echo Enviando al servidor local http://127.0.0.1:8787 ...
node server\local-importer.mjs --dir "%ROMDIR%" --device "%DEVID%" --post http://127.0.0.1:8787
if errorlevel 1 (
  echo.
  echo No se pudo subir. Abre primero Iniciar_Arkaios_Node_Server.bat y vuelve a ejecutar este importador.
)

:end
pause
