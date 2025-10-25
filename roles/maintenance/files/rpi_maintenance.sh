#!/usr/bin/env bash
set -euo pipefail

# ===== Config del gating APT cada N días =====
STATE_DIR="/var/lib/rpi-maintenance"
STAMP="$STATE_DIR/last_apt_maintenance"
DAYS="${APT_EVERY_DAYS:-30}"
SECS=$(( DAYS * 24 * 3600 ))
mkdir -p "$STATE_DIR"

now="$(date +%s)"
do_apt=1

if [[ -f "$STAMP" ]]; then
  last="$(date -r "$STAMP" +%s || echo 0)"
  if (( last + SECS > now )); then
    do_apt=0
  fi
fi

# Permite forzar APT manualmente: rpi_maintenance.sh --force-apt
if [[ "${1:-}" == "--force-apt" ]]; then
  do_apt=1
fi

if (( do_apt == 1 )); then
  echo "[rpi-maintenance] Ejecutando APT (≥ ${DAYS}d desde la última vez)…"
  apt update
  DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
  apt autoremove -y
  apt clean
  touch "$STAMP"

  # ← REINICIO SOLO CUANDO SÍ HUBO MANTENIMIENTO
  #    (o sea ~1 vez cada 30 días) Y SOLO si el sistema lo pide.
  if [[ -f /var/run/reboot-required ]]; then
    echo "[rpi-maintenance] reboot-required detectado. Reiniciando..."
    systemctl reboot
  fi
else
  echo "[rpi-maintenance] APT omitido (última < ${DAYS}d)."
fi

# ===== Tareas diarias (estas sí corren todos los días a las 3am) =====
# Mantén 2 días de logs (puedes subirlo a 7d si quieres más historial)
journalctl --vacuum-time=2d

# Limpieza temporal y logs
rm -rf /tmp/* /var/tmp/*

for f in /var/log/*.log; do
  [[ -f "$f" ]] && truncate -s 0 "$f" || true
done