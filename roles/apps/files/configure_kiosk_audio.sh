#!/usr/bin/env bash
set -u

# Prepara el audio HDMI para el kiosk y escribe SOLO el nombre del sink
# en stdout. Los mensajes de diagnostico van a stderr.
#
# Uso:
#   configure_kiosk_audio.sh HDMI-A-1 100
#   configure_kiosk_audio.sh HDMI-A-2 100

CONNECTOR="${1:-HDMI-A-1}"
VOLUME="${2:-100}"
# pactl acepta porcentaje; la variable se guarda sin % para evitar que systemd
# interprete el caracter como un specifier dentro de ExecStart.
case "$VOLUME" in
  *%) PACTL_VOLUME="$VOLUME" ;;
  *)  PACTL_VOLUME="${VOLUME}%" ;;
esac

case "$CONNECTOR" in
  HDMI-A-1)
    HDMI_INDEX=0
    ;;
  HDMI-A-2)
    HDMI_INDEX=1
    ;;
  *)
    echo "[audio] Conector desconocido '$CONNECTOR'; se usara HDMI-A-1." >&2
    HDMI_INDEX=0
    ;;
esac

UID_NOW="$(id -u)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${UID_NOW}}"
export PULSE_SERVER="${PULSE_SERVER:-unix:${XDG_RUNTIME_DIR}/pulse/native}"

# PipeWire/Pulse es un servicio de usuario. En algunos boots tarda unos
# segundos mas que systemd/LightDM, asi que esperamos a que realmente responda.
PULSE_READY=0
for _ in $(seq 1 30); do
  if [ -S "${XDG_RUNTIME_DIR}/pulse/native" ] && pactl info >/dev/null 2>&1; then
    PULSE_READY=1
    break
  fi
  sleep 1
done

if [ "$PULSE_READY" -ne 1 ]; then
  echo "[audio] PipeWire/Pulse no estuvo disponible despues de 30 s." >&2
  exit 1
fi

# HDMI-A-1 corresponde a vc4hdmi0 y HDMI-A-2 a vc4hdmi1.
ALSA_SHORT_NAME="vc4hdmi${HDMI_INDEX}"
ALSA_CARD_NUM="$(awk -v target="$ALSA_SHORT_NAME" '
  $0 ~ "\\[" target "[[:space:]]*\\]" {
    line=$0
    sub(/^[[:space:]]+/, "", line)
    split(line, fields, /[[:space:]]+/)
    print fields[1]
    exit
  }
' /proc/asound/cards 2>/dev/null || true)"

# Busca el nombre de la card Pulse/PipeWire que corresponde a esa card ALSA.
# En boot la card HDMI puede aparecer unos segundos despues que pipewire-pulse.
PULSE_CARD=""
for _ in $(seq 1 30); do
  if [ -n "$ALSA_CARD_NUM" ]; then
    PULSE_CARD="$(pactl list cards 2>/dev/null | awk -v target="$ALSA_CARD_NUM" '
      /^Card #[0-9]+/ { card="" }
      /^[[:space:]]*Name:[[:space:]]+/ { card=$2 }
      /alsa.card = "/ {
        value=$0
        sub(/^.*alsa.card = "/, "", value)
        sub(/".*$/, "", value)
        if (value == target && card != "") {
          print card
          exit
        }
      }
    ')"
  fi

  # Fallback para sistemas donde pactl no exponga alsa.card en el bloque.
  if [ -z "$PULSE_CARD" ]; then
    HDMI_POSITION=$((HDMI_INDEX + 1))
    PULSE_CARD="$(pactl list short cards 2>/dev/null | awk '$2 ~ /\.hdmi$/ {print $2}' | sed -n "${HDMI_POSITION}p")"
  fi

  [ -n "$PULSE_CARD" ] && break
  sleep 0.5
done

if [ -z "$PULSE_CARD" ]; then
  echo "[audio] No se encontro la card PipeWire/Pulse para ${CONNECTOR} (${ALSA_SHORT_NAME})." >&2
  exit 1
fi

echo "[audio] Activando ${PULSE_CARD} -> output:hdmi-stereo" >&2
PROFILE_READY=0
for _ in $(seq 1 20); do
  if pactl set-card-profile "$PULSE_CARD" output:hdmi-stereo >/dev/null 2>&1; then
    PROFILE_READY=1
    break
  fi
  sleep 0.5
done

if [ "$PROFILE_READY" -ne 1 ]; then
  echo "[audio] No se pudo activar el perfil HDMI en ${PULSE_CARD}." >&2
  exit 1
fi

# Espera a que PipeWire publique el sink despues de activar el perfil.
SINK=""
for _ in $(seq 1 20); do
  if [ -n "$ALSA_CARD_NUM" ]; then
    SINK="$(pactl list sinks 2>/dev/null | awk -v target="$ALSA_CARD_NUM" '
      /^Sink #[0-9]+/ { sink="" }
      /^[[:space:]]*Name:[[:space:]]+/ { sink=$2 }
      /alsa.card = "/ {
        value=$0
        sub(/^.*alsa.card = "/, "", value)
        sub(/".*$/, "", value)
        if (value == target && sink != "") {
          print sink
          exit
        }
      }
    ')"
  fi

  # Fallback: normalmente solo el HDMI seleccionado tiene perfil activo.
  if [ -z "$SINK" ]; then
    SINK="$(pactl list short sinks 2>/dev/null | awk '$2 ~ /hdmi.*hdmi-stereo/ {print $2; exit}')"
  fi

  [ -n "$SINK" ] && break
  sleep 0.5
done

if [ -z "$SINK" ]; then
  echo "[audio] El perfil HDMI se activo, pero no aparecio ningun sink HDMI." >&2
  exit 1
fi

# El default se deja configurado para otras aplicaciones, pero Electron recibe
# tambien PULSE_SINK de forma explicita porque WirePlumber puede volver a elegir
# el fallback cuando marca HDMI como 'available: no'.
pactl set-sink-mute "$SINK" 0 >/dev/null 2>&1 || true
pactl set-sink-volume "$SINK" "$PACTL_VOLUME" >/dev/null 2>&1 || true
pactl set-default-sink "$SINK" >/dev/null 2>&1 || true

echo "[audio] Sink HDMI listo: ${SINK}" >&2
printf '%s\n' "$SINK"
