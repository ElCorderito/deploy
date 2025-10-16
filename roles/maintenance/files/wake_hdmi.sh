#!/usr/bin/env bash
set -e

# Enciende la salida de video del Pi (Bookworm/VC4)
if command -v vcgencmd >/dev/null 2>&1; then
  vcgencmd display_power 1 || true
fi

# Si ya hay X, fuerza DPMS ON en :0
export DISPLAY=:0
export XAUTHORITY="/home/{{ kiosk_user }}/.Xauthority"
for i in {1..8}; do
  xset dpms force on 2>/dev/null || true
  sleep 1
done

# Si hay CEC, despierta la TV y marca fuente activa
if command -v cec-ctl >/dev/null 2>&1; then
  cec-ctl --to 0 --image-view-on --active-source || true
fi