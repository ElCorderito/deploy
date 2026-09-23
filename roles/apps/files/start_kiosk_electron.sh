#!/usr/bin/env bash
set -u

# Wrapper de arranque de Electron.
# Configura el entorno PipeWire/Pulse con el UID real del usuario y, si es
# posible, fuerza Electron a usar explicitamente el sink HDMI correcto.

CONNECTOR="${1:-HDMI-A-1}"
VOLUME="${2:-100}"

UID_NOW="$(id -u)"
export XDG_RUNTIME_DIR="/run/user/${UID_NOW}"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"
export PIPEWIRE_LATENCY="128/48000"

HDMI_SINK=""
if HDMI_SINK="$(/usr/local/bin/configure_kiosk_audio.sh "$CONNECTOR" "$VOLUME")"; then
  if [ -n "$HDMI_SINK" ]; then
    export PULSE_SINK="$HDMI_SINK"
    echo "[audio] Electron usara PULSE_SINK=${PULSE_SINK}" >&2
  fi
else
  echo "[audio] No se pudo preparar HDMI; Electron arrancara de todos modos." >&2
fi

exec /usr/bin/npm run electron
