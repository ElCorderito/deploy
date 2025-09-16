#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="/opt/electron_rasp/electron_rasp"
cd "$REPO_DIR"
git update-index --skip-worktree flask_app/data/data.json || true
git fetch origin
git reset --hard origin/$(git symbolic-ref --short HEAD)
git clean -fd
changed=$(git rev-list --count HEAD@{1}..HEAD)
if [[ $changed -gt 0 ]]; then
  echo "[update_repo.sh] Repo actualizado – reiniciando servicios"
  sudo systemctl restart electron_rasp-flask.service
  sudo systemctl restart electron_rasp-electron.service
else
  echo "[update_repo.sh] Ya estaba al día – nada que hacer"
fi
