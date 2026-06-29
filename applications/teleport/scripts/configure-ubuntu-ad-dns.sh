#!/usr/bin/env bash
set -euo pipefail

# Configure le DNS Active Directory sur l'hôte Ubuntu qui exécute le Windows Desktop Service.

#

# Usage :

# sudo ./applications/teleport/scripts/configure-ubuntu-ad-dns.sh

#

# Variables optionnelles :

# NET_IFACE=ens33

# AD_DNS_SERVER=192.168.1.50

# AD_DOMAIN=rt.local

NET_IFACE="${NET_IFACE:-ens33}"
AD_DNS_SERVER="${AD_DNS_SERVER:-192.168.1.50}"
AD_DOMAIN="${AD_DOMAIN:-rt.local}"

echo "[1/4] Configuration DNS systemd-resolved..."
resolvectl dns "${NET_IFACE}" "${AD_DNS_SERVER}"
resolvectl domain "${NET_IFACE}" "${AD_DOMAIN}"

echo "[2/4] Statut DNS..."
resolvectl status

echo "[3/4] Tests DNS AD..."
getent hosts "DC01.${AD_DOMAIN}" || true

if command -v host >/dev/null 2>&1; then
host "DC01.${AD_DOMAIN}" || true
host "_ldap._tcp.dc._msdcs.${AD_DOMAIN}" || true
else
echo "[WARN] Commande 'host' absente. Installer bind9-host si nécessaire."
fi

echo "[4/4] Terminé."
