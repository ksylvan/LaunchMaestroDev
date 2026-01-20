# Maestro Launcher

A macOS application launcher for Maestro development that runs your worktree in a dev server.

## What It Does

This creates a double-clickable macOS `.app` bundle that:

- Navigates to your Maestro worktree directory
- Resets any uncommitted changes
- Sets up a Python virtual environment (if needed)
- Installs npm dependencies
- Starts the Vite dev server on port 5199
- Monitors the Electron process and cleans up when you close the window

## Setup

1. **Configure your worktree path**

   Edit `config.sh` and set `MAESTRO_WORKTREE_DIR` to your Maestro worktree location:

   ```bash
   MAESTRO_WORKTREE_DIR="$HOME/src/worktrees/Maestro/preview"
   ```

2. **Run the installer**

   ```bash
   ./install.sh
   ```

   This will copy the launcher to `~/Desktop/Maestro.app`

3. **Launch Maestro**

   Double-click `Maestro.app` on your Desktop!

## Logs

All output is logged to `~/Desktop/MaestroPreview.log` for debugging.

## Requirements

- macOS
- A Maestro git worktree
- Homebrew (with `uv` and `npm` available in `/opt/homebrew/bin`)
- Node.js and Python 3.11

## How It Works

The `.app` bundle structure:

```text
Maestro.app/
├── Contents/
│   ├── Info.plist          # App metadata
│   ├── MacOS/
│   │   └── launch.sh       # Main launch script
│   └── Resources/
│       └── icon.icns       # App icon
```

The launcher reads configuration from `config.sh` at the root of this directory, which is sourced during the build process.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
