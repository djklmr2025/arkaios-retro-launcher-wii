# ARKAIOS Server Installer

Pack para convertir una PC vieja en servidor local ARKAIOS.

Este pack no instala el sistema operativo. Primero instala Debian/Ubuntu/Linux Mint en la PC vieja o arranca un Live USB Linux. Luego ejecuta:

```bash
cd /media/$USER/ARKAIOS_SETUP/server-installer
chmod +x install-linux.sh
./install-linux.sh
```

## Que instala

- Node.js
- Git
- ARKAIOS Retro Launcher Wii
- Servicio systemd `arkaios-node`
- Carpetas persistentes en `/arkaios`

## Servicio

```bash
sudo systemctl status arkaios-node
sudo systemctl restart arkaios-node
sudo journalctl -u arkaios-node -f
```

Servidor local:

```text
http://IP-DEL-SERVIDOR:8787
```

## Politica

El servidor maneja catalogos, saves, covers, homebrew y metadata. No distribuye ROMs comerciales.
