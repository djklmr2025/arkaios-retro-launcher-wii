ARKAIOS SERVER SETUP

Este pendrive prepara una PC vieja como servidor local ARKAIOS.

IMPORTANTE:
Este pendrive NO es todavia un Linux booteable completo. Es el pack instalador.
Primero arranca la PC vieja con Debian, Ubuntu, Linux Mint o un Live USB Linux.

En Linux:

1. Abre Terminal.
2. Entra a la memoria:
   cd /media/$USER/ARKAIOS_SETUP/ARKAIOS_SERVER_SETUP/server-installer

   Si el nombre de montaje cambia, abre la memoria desde el explorador y copia la ruta.

3. Ejecuta:
   chmod +x install-linux.sh
   sudo ./install-linux.sh

4. Al terminar, abre desde otra computadora:
   http://IP-DEL-SERVIDOR:8787/health

En Windows:

1. Abre PowerShell como administrador.
2. Ejecuta:
   powershell -ExecutionPolicy Bypass -File D:\ARKAIOS_SERVER_SETUP\server-installer\install-windows.ps1

Uso recomendado:
- Linux para servidor 24/7.
- Windows solo para pruebas.

El servidor maneja metadata, catalogos, saves, covers, homebrew y parches.
No distribuye ROMs comerciales.
