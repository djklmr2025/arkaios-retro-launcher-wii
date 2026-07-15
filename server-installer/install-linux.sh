#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
elif [[ -f "${SCRIPT_DIR}/config.env.example" ]]; then
  # shellcheck disable=SC1090
  source "${SCRIPT_DIR}/config.env.example"
fi

ARKAIOS_USER="${ARKAIOS_USER:-arkaios}"
ARKAIOS_HOME="${ARKAIOS_HOME:-/arkaios}"
ARKAIOS_REPO="${ARKAIOS_REPO:-https://github.com/djklmr2025/arkaios-retro-launcher-wii.git}"
ARKAIOS_NODE_HOST="${ARKAIOS_NODE_HOST:-0.0.0.0}"
ARKAIOS_NODE_PORT="${ARKAIOS_NODE_PORT:-8787}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Ejecuta con sudo: sudo ./install-linux.sh"
  exit 1
fi

echo "[ARKAIOS] Instalando dependencias..."
if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ca-certificates curl git nodejs npm
else
  echo "Este instalador requiere una distro con apt-get para la fase inicial."
  exit 1
fi

echo "[ARKAIOS] Creando usuario y carpetas..."
if ! id "${ARKAIOS_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --shell /usr/sbin/nologin "${ARKAIOS_USER}"
fi

mkdir -p "${ARKAIOS_HOME}/server" "${ARKAIOS_HOME}/data" "${ARKAIOS_HOME}/saves" "${ARKAIOS_HOME}/catalogs" "${ARKAIOS_HOME}/patches" "${ARKAIOS_HOME}/covers" "${ARKAIOS_HOME}/backups"
chown -R "${ARKAIOS_USER}:${ARKAIOS_USER}" "${ARKAIOS_HOME}"

echo "[ARKAIOS] Clonando/actualizando repo..."
if [[ -d "${ARKAIOS_HOME}/server/.git" ]]; then
  git -C "${ARKAIOS_HOME}/server" pull --ff-only
else
  git clone "${ARKAIOS_REPO}" "${ARKAIOS_HOME}/server"
fi

cd "${ARKAIOS_HOME}/server"
npm install --omit=dev
chown -R "${ARKAIOS_USER}:${ARKAIOS_USER}" "${ARKAIOS_HOME}/server"

echo "[ARKAIOS] Instalando servicio systemd..."
cat >/etc/systemd/system/arkaios-node.service <<SERVICE
[Unit]
Description=ARKAIOS Wii Node Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${ARKAIOS_USER}
WorkingDirectory=${ARKAIOS_HOME}/server
Environment=ARKAIOS_NODE_HOST=${ARKAIOS_NODE_HOST}
Environment=ARKAIOS_NODE_PORT=${ARKAIOS_NODE_PORT}
Environment=ARKAIOS_NODE_DATA=${ARKAIOS_HOME}/data
ExecStart=/usr/bin/node server/arkaios-node-server.mjs
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now arkaios-node

IP_ADDR="$(hostname -I | awk '{print $1}')"
echo
echo "[ARKAIOS] Instalacion completada."
echo "Servidor: http://${IP_ADDR:-IP-DEL-SERVIDOR}:${ARKAIOS_NODE_PORT}"
echo "Estado:   sudo systemctl status arkaios-node"
