#!/bin/bash

cd "$(dirname "$0")" || exit 1

PATH=/opt/homebrew/bin:"$PATH"
export PATH

# shellcheck disable=SC1091
source ../../config.sh

# Create log file
LOG_FILE="${LOG_FILE:-$HOME/Desktop/MaestroPreview.log}"

# Redirect all output to log file
exec > "$LOG_FILE" 2>&1

echo "=== Launch started at $(date) ==="

cd "${MAESTRO_WORKTREE_DIR}" || exit 1
if [[ ! -d .venv ]]; then
  uv venv -p 3.11
fi

# shellcheck source=/dev/null
source .venv/bin/activate
npm install

# package-lock.json might get updated, reset it
git checkout -f package-lock.json

# Start the dev server in background
VITE_PORT="${VITE_PORT:-5199}" npm run dev &
DEV_PID=$!
sleep 120

echo "Dev server started with PID $DEV_PID"

# Monitor for Electron process with VITE_PORT=5199
while true; do
  sleep 5
  if ! ps eww -p $DEV_PID > /dev/null 2>&1; then
    echo "Dev server process died, exiting monitor"
    break
  fi

  # shellcheck disable=SC2009
  if ! ps eww | grep -q "VITE_PORT=5199.*electron"; then
    echo "No Electron window found for VITE_PORT=5199, cleaning up..."
    kill $DEV_PID 2>/dev/null
    pkill -f "worktrees/Maestro/preview"
    break
  fi
done

echo "=== Launch completed at $(date) ==="
