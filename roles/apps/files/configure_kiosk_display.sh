#!/usr/bin/env bash
set -u

# Uso:
#   configure_kiosk_display.sh portrait
#   configure_kiosk_display.sh portrait-left
#   configure_kiosk_display.sh landscape
#
# Si no se pasa orientación, no hace nada. Así las Raspberry existentes
# conservan exactamente su comportamiento actual.
ORIENTATION="${1:-}"

case "$ORIENTATION" in
  "")
    exit 0
    ;;
  landscape|normal)
    ROTATION="normal"
    ;;
  portrait|portrait-right|right)
    ROTATION="right"
    ;;
  portrait-left|left)
    ROTATION="left"
    ;;
  *)
    echo "[display] Orientación desconocida: $ORIENTATION" >&2
    exit 0
    ;;
esac

: "${DISPLAY:=:0}"

# Espera brevemente a que X y la salida física estén disponibles.
OUTPUT=""
for _ in $(seq 1 20); do
  OUTPUT="$(xrandr --query 2>/dev/null | awk '$2 == "connected" { print $1; exit }')"
  [ -n "$OUTPUT" ] && break
  sleep 0.5
done

if [ -z "$OUTPUT" ]; then
  echo "[display] No se encontró una salida conectada; se continúa sin rotar." >&2
  exit 0
fi

echo "[display] Aplicando '$ROTATION' a '$OUTPUT'"
if ! xrandr --output "$OUTPUT" --rotate "$ROTATION"; then
  echo "[display] xrandr no pudo aplicar la rotación; se continúa sin bloquear Electron." >&2
fi

exit 0
