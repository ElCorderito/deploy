#!/usr/bin/env bash
set -euo pipefail

apt update
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
apt autoremove -y
apt clean

# Mantén 2 días (como en tu Pi). Cambia a 7d si prefieres.
journalctl --vacuum-time=2d

rm -rf /tmp/* /var/tmp/*

for f in /var/log/*.log; do
  [ -f "$f" ] && truncate -s 0 "$f"
done

# Opcional: reiniciar si el sistema lo requiere
# if [ -f /var/run/reboot-required ]; then systemctl reboot; fi
