#!/usr/bin/env bash
set -euo pipefail

# Installe le Teleport Windows Desktop Service sur l'hôte Ubuntu.

#

# Ce script ne modifie PAS /etc/teleport.yaml.

# Il crée uniquement :

# - /etc/teleport-windows.yaml

# - /etc/systemd/system/teleport-windows.service

# - /var/lib/teleport-windows

#

# Usage :

# export TELEPORT_JOIN_TOKEN="token_windowsdesktop_ici"

# sudo -E ./applications/teleport/scripts/install-windows-desktop-service.sh

#

# Variables optionnelles :

# TELEPORT_PROXY="teleport.local:443"

# TELEPORT_CA_PIN="sha256:..."

# TELEPORT_NODE_NAME="ubuntu-windows-desktop"

# AD_LDAP_ADDR="DC01.rt.local:636"

# AD_DOMAIN="rt.local"

# AD_BASE_DN="DC=rt,DC=local"

# AD_SVC_USERNAME="RT\svc-teleport"

# AD_SVC_SID="S-1-5-21-..."

: "${TELEPORT_JOIN_TOKEN:?Variable TELEPORT_JOIN_TOKEN obligatoire. Génère un token avec: tctl tokens add --type=windowsdesktop --ttl=1h}"

TELEPORT_PROXY="${TELEPORT_PROXY:-teleport.local:443}"
TELEPORT_CA_PIN="${TELEPORT_CA_PIN:-sha256:6fbdb62a6895db952b0d75f4f313972ac65e714d4624c7acfd8b2be5c4548bd5}"
TELEPORT_NODE_NAME="${TELEPORT_NODE_NAME:-ubuntu-windows-desktop}"

AD_LDAP_ADDR="${AD_LDAP_ADDR:-DC01.rt.local:636}"
AD_DOMAIN="${AD_DOMAIN:-rt.local}"
AD_BASE_DN="${AD_BASE_DN:-DC=rt,DC=local}"
AD_SVC_USERNAME="${AD_SVC_USERNAME:-RT\svc-teleport}"
AD_SVC_SID="${AD_SVC_SID:-S-1-5-21-4124763732-3442043943-3729823684-1104}"

TELEPORT_BIN="$(command -v teleport || true)"

if [ -z "${TELEPORT_BIN}" ]; then
echo "[ERREUR] Le binaire teleport est introuvable."
exit 1
fi

echo "[1/7] Vérification de la résolution DNS..."
getent hosts DC01.rt.local || {
echo "[WARN] DC01.rt.local ne se résout pas via getent."
echo "[WARN] Vérifie le DNS AD avant de continuer."
}

echo "[2/7] Vérification du port LDAPS..."
timeout 5 bash -c '</dev/tcp/DC01.rt.local/636' 2>/dev/null || {
echo "[WARN] Impossible de joindre DC01.rt.local:636."
echo "[WARN] Vérifie LDAPS, le firewall et la résolution DNS."
}

echo "[3/7] Création du data_dir..."
install -d -m 0700 /var/lib/teleport-windows

echo "[4/7] Écriture de /etc/teleport-windows.yaml..."
cat > /etc/teleport-windows.yaml <<YAML
version: v3

teleport:
nodename: ${TELEPORT_NODE_NAME}
data_dir: /var/lib/teleport-windows
proxy_server: ${TELEPORT_PROXY}
ca_pin: "${TELEPORT_CA_PIN}"
join_params:
token_name: "${TELEPORT_JOIN_TOKEN}"
method: token
log:
output: stderr
severity: INFO
format:
output: text

auth_service:
enabled: "no"

proxy_service:
enabled: "no"

ssh_service:
enabled: "no"

windows_desktop_service:
enabled: "yes"
ldap:
addr: "${AD_LDAP_ADDR}"
domain: "${AD_DOMAIN}"
username: '${AD_SVC_USERNAME}'
sid: "${AD_SVC_SID}"
discovery_configs:
- base_dn: "${AD_BASE_DN}"
labels:
env: lab
domain: ${AD_DOMAIN}
YAML

chmod 600 /etc/teleport-windows.yaml

echo "[5/7] Écriture du service systemd teleport-windows.service..."
cat > /etc/systemd/system/teleport-windows.service <<SERVICE
[Unit]
Description=Teleport Windows Desktop Service
After=network-online.target teleport.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=${TELEPORT_BIN} start --config=/etc/teleport-windows.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

echo "[6/7] Activation du service..."
systemctl daemon-reload
systemctl enable --now teleport-windows

echo "[7/7] Statut du service..."
systemctl status teleport-windows --no-pager -l || true

echo
echo "Logs :"
echo "  sudo journalctl -u teleport-windows -n 100 --no-pager"
echo "  sudo journalctl -u teleport-windows -f"
echo
echo "Vérification côté Teleport :"
echo "  kubectl -n teleport exec deploy/teleport-cluster-auth -- tctl get windows_desktop"
