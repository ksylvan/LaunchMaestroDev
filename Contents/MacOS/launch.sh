#!/bin/bash

cd "$(dirname "$0")" || exit 1

PATH=/opt/homebrew/bin:"$PATH"
export PATH

# shellcheck disable=SC1091
source ../../config.sh

# Create log file
LOG_FILE="${LOG_FILE:-$HOME/Desktop/MaestroDev.log}"

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
NPM_PID=$!

echo "Starting dev server (npm PID: $NPM_PID)"
echo "Waiting for Electron to launch..."

# Wait for Electron to actually start (give it up to 3 minutes)
ELECTRON_PID=""
for i in {1..36}; do
  sleep 5

  # Find the Electron process by looking for the actual Electron binary
  # running from the Maestro directory
  FOUND_PID=$(pgrep -f "Electron.*${MAESTRO_WORKTREE_DIR}" | head -n 1)

  if [ -n "$FOUND_PID" ]; then
    ELECTRON_PID=$FOUND_PID
    echo "Electron started with PID $ELECTRON_PID after $((i * 5)) seconds"
    break
  fi

  echo "Still waiting for Electron to launch... ($((i * 5))s elapsed)"
done

if [ -z "$ELECTRON_PID" ]; then
  echo "ERROR: Electron failed to start within 3 minutes"
  echo "Cleaning up npm process and exiting..."
  kill $NPM_PID 2>/dev/null
  pkill -f "worktrees/Maestro/preview"
  exit 1
fi

# Monitor: Keep running as long as Electron is alive
echo "Monitoring Electron process (PID: $ELECTRON_PID)..."
while true; do
  sleep 10

  # Check if Electron is still running
  if ! ps -p $ELECTRON_PID > /dev/null 2>&1; then
    echo "Electron process (PID: $ELECTRON_PID) has exited"
    echo "Cleaning up dev server..."
    kill $NPM_PID 2>/dev/null
    pkill -f "worktrees/Maestro/preview"
    break
  fi
done

echo "=== Launch completed at $(date) ==="
