#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [[ ! -f "$SCRIPT_DIR/config.sh" ]]; then
    echo "Error: config.sh not found. Please create it first."
    echo "You can copy config.sh.example to config.sh and edit it."
    exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

# Validate that MAESTRO_WORKTREE_DIR is set
if [[ -z "$MAESTRO_WORKTREE_DIR" ]]; then
    echo "Error: MAESTRO_WORKTREE_DIR is not set in config.sh"
    exit 1
fi

# Check if the worktree directory exists
if [[ ! -d "$MAESTRO_WORKTREE_DIR" ]]; then
    echo "Warning: Maestro worktree directory does not exist: $MAESTRO_WORKTREE_DIR"
    echo "The launcher will be created, but it won't work until this directory exists."
fi

# Check if worktree is actually a git worktree
if [[ -d "$MAESTRO_WORKTREE_DIR/.git" ]]; then
    if ! grep -q "gitdir:" "$MAESTRO_WORKTREE_DIR/.git" 2>/dev/null; then
        echo "Warning: $MAESTRO_WORKTREE_DIR appears to be a regular git repo, not a worktree."
    fi
fi

# Remove existing app if it exists
if [[ -d "$DESKTOP_APP_PATH" ]]; then
    echo "Removing existing MaestroDev.app..."
    rm -rf "$DESKTOP_APP_PATH"
fi

# Now create the app bundle
mkdir -p "$DESKTOP_APP_PATH/"
cp -R "$SCRIPT_DIR/Contents" "$DESKTOP_APP_PATH/"
cp "$SCRIPT_DIR/config.sh" "$DESKTOP_APP_PATH/"

echo ""
echo "✅ Installation complete!"
echo ""
echo "MaestroDev.app has been installed to: $DESKTOP_APP_PATH"
echo "Configured for worktree: $MAESTRO_WORKTREE_DIR"
echo ""
echo "Double-click MaestroDev.app to launch!"
echo "Logs will be written to: ${LOG_FILE:-$MAESTRO_WORKTREE_DIR/MaestroDev.log}"
