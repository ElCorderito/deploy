#!/usr/bin/env bash
cd /opt/signage/signage
changed=$(git pull --rebase --stat | grep -c 'files changed' || true)
if [ "$changed" -gt 0 ]; then
  echo "[signage/signage/update.sh] cambios detectados → reiniciando electron_rasp"
  sudo /usr/bin/systemctl restart electron_rasp-flask.service
  sudo /usr/bin/systemctl restart electron_rasp-electron.service
fi
