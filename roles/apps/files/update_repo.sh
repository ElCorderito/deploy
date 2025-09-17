#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="{{ electron_root }}/electron_rasp"
cd "$REPO_DIR"

# Proteger el data.json SOLO si existe y está trackeado
DATA_FILE="flask_app/data/data.json"
if [[ -f "$DATA_FILE" ]] && git ls-files --error-unmatch "$DATA_FILE" >/dev/null 2>&1; then
  git update-index --skip-worktree "$DATA_FILE" || true
fi

# Fetch + reset duro a la rama por defecto del remoto
# (sigue la rama apuntada por origin/HEAD)
git fetch origin
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##')
git reset --hard "origin/${DEFAULT_BRANCH}"
git clean -fd

# ¿Se movió HEAD?
changed=$(git rev-list --count HEAD@{1}..HEAD || echo 0)

if [[ ${changed:-0} -gt 0 ]]; then
  echo "[update_repo.sh] Repo actualizado – reiniciando servicios"
  sudo systemctl restart electron_rasp-flask.service
  sudo systemctl restart electron_rasp-electron.service
else
  echo "[update_repo.sh] Ya estaba al día – nada que hacer"
fi