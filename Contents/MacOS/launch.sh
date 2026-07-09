#!/bin/bash

set -e

# Force native arm64 on Apple Silicon.
#
# This .app's CFBundleExecutable is THIS script, so launchd execs the universal
# /bin/bash via the shebang. LSArchitecturePriority / LSRequiresNativeExecution
# in Info.plist select the slice of a Mach-O *app* binary — they do NOT govern a
# script bundle's shebang interpreter, so /bin/bash can still come up as x86_64
# (Rosetta). That x86_64 cpu-type preference is then inherited by every child
# (npm, node, Electron, the agent shell, and any cmake/clang it spawns),
# silently producing x86_64 builds on an arm64 machine. Re-exec ourselves under
# `arch -arm64` so the whole process tree is native. Gated on the HARDWARE flag
# (hw.optional.arm64), so it is a no-op on real Intel hosts; the MAESTRO_NATIVE
# guard prevents an exec loop.
if [[ -z "${MAESTRO_NATIVE_REEXEC:-}" \
      && "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" == "1" \
      && "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" == "1" ]]; then
    export MAESTRO_NATIVE_REEXEC=1
    exec arch -arm64 /bin/bash "$0" "$@"
fi

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

# Check for nvm
if [ -d "$HOME/.nvm" ]; then
    # shellcheck source=/dev/null
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
    nvm use default 2>/dev/null || true
    # nvm use won't reorder PATH when the version is already present (from launchd
    # user-session env). The script's own PATH=/opt/homebrew/bin:... prepend then
    # puts /opt/homebrew/bin/node (v26) ahead of the nvm node (v25). Fix by
    # explicitly prepending the nvm default bin dir so it wins unconditionally.
    NVM_DEFAULT_NODE="$(nvm which default 2>/dev/null)"
    if [ -n "$NVM_DEFAULT_NODE" ] && [ -x "$NVM_DEFAULT_NODE" ]; then
        export PATH="$(dirname "$NVM_DEFAULT_NODE"):$PATH"
    fi
    hash -r 2>/dev/null || true
fi
echo "[debug] PATH=$PATH"
echo "[debug] node: $(command -v node) -> $(node --version 2>/dev/null)"
echo "[debug] npm:  $(command -v npm) -> $(npm --version 2>/dev/null)"

# Global variables for PIDs
NPM_PID=""
WEB_PID=""
ELECTRON_PID=""

# Cleanup function - kills all spawned processes
cleanup() {
    local exit_code=$?

    echo ""
    echo "Cleaning up dev servers..."

    if [ -n "$NPM_PID" ]; then
        kill "$NPM_PID" 2>/dev/null || true
    fi

    if [ -n "$WEB_PID" ]; then
        kill "$WEB_PID" 2>/dev/null || true
    fi

    # Kill any remaining processes from this worktree
    pkill -f "${MAESTRO_WORKTREE_DIR}" 2>/dev/null || true

    echo "=== Launch completed at $(date) ==="
    exit "$exit_code"
}

# Set up trap to ensure cleanup runs on exit or interruption
trap cleanup EXIT INT TERM

# Navigate to worktree and set up environment
cd "${MAESTRO_WORKTREE_DIR}" || exit 1

if [[ ! -d .venv ]]; then
    echo "Creating Python virtual environment..."
    uv venv -p 3.11
fi

# shellcheck source=/dev/null
source .venv/bin/activate

echo "Installing npm dependencies..."
npm install

echo "Building web interface assets..."
npm run build:web-desktop

echo "Building the CLI..."
npm run build:cli

# package-lock.json might get updated, reset it
git checkout -f package-lock.json

# Start the main dev server in background
echo "Starting main dev server (port: ${VITE_PORT:-5198})..."
VITE_PORT="${VITE_PORT:-5198}" npm run dev &
NPM_PID=$!

# Start the web interface dev server in background
echo "Starting web interface server (port: ${VITE_WEB_PORT:-5199})..."
VITE_WEB_PORT="${VITE_WEB_PORT:-5199}" npm run dev:web-desktop &
WEB_PID=$!

echo "Dev servers started:"
echo "  - Main renderer: PID $NPM_PID (port ${VITE_PORT:-5198})"
echo "  - Web interface: PID $WEB_PID (port ${VITE_WEB_PORT:-5199})"
echo ""
echo "Waiting for Electron to launch..."

# Wait for Electron to actually start (give it up to 3 minutes)
for i in {1..36}; do
    sleep 5

    # Find the Electron process by looking for the actual Electron binary
    # running from the Maestro directory
    FOUND_PID=$(pgrep -f "Electron.*${MAESTRO_WORKTREE_DIR}" | head -n 1)

    if [ -n "$FOUND_PID" ]; then
        ELECTRON_PID=$FOUND_PID
        echo "✓ Electron started with PID $ELECTRON_PID after $((i * 5)) seconds"
        break
    fi

    if (( i % 6 == 0 )); then
        echo "  Still waiting for Electron... ($((i * 5))s elapsed)"
    fi
done

if [ -z "$ELECTRON_PID" ]; then
    echo "✗ ERROR: Electron failed to start within 3 minutes"
    exit 1
fi

# Monitor: Keep running as long as Electron is alive
echo "Monitoring Electron process (PID: $ELECTRON_PID)..."
echo ""

while true; do
    sleep 10

    # Check if Electron is still running
    if ! ps -p "$ELECTRON_PID" > /dev/null 2>&1; then
        echo "Electron process (PID: $ELECTRON_PID) has exited"
        break
    fi
done

# Cleanup trap will handle the rest
