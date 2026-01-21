#!/bin/bash

# Configuration for Maestro Launcher
# DO NOT EDIT install.sh directly; instead, edit this config.sh file.

# Path to the Desktop App (optional - defaults to $HOME/Desktop/MaestroDev.app)
# shellcheck disable=SC2034
DESKTOP_APP_PATH="$HOME/Desktop/MaestroDev.app"

# Path to your Maestro git worktree
# Example: "$HOME/src/worktrees/Maestro/preview"
MAESTRO_WORKTREE_DIR="$HOME/src/worktrees/Maestro/preview"

# Vite port for main renderer (optional - defaults to 5198)
# shellcheck disable=SC2034
VITE_PORT=5198

# Vite port for web interface (optional - defaults to 5199)
# shellcheck disable=SC2034
VITE_WEB_PORT=5199

# Log file location (optional)
# shellcheck disable=SC2034
LOG_FILE="$MAESTRO_WORKTREE_DIR/MaestroDev.log"
