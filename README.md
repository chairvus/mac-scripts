# mac-scripts 🧹

A collection of bash scripts for macOS maintenance & cleanup.

---

## Scripts

### `clean_uninstall.sh` — Clean App Uninstaller
Removes an app along with all leftover files (containers, caches, preferences, defaults database, etc.) thoroughly.

**Features:**
- Auto-detects bundle ID from the app
- Uses `mdfind` to track all app-related files (more accurate than AppCleaner)
- Scans: Containers, Group Containers, App Support, Caches, Logs, Preferences, LaunchAgents, Saved State, HTTPStorages, WebKit, `/private/var/folders`, defaults database
- Kills the app automatically before uninstalling
- Dry-run mode (preview without deleting)
- Deduplicates results
- Handles system-level files with sudo separately

```bash
# Preview first (safe)
bash clean_uninstall.sh "Spotify" --dry-run

# Uninstall with auto-detected bundle ID
bash clean_uninstall.sh "Spotify"

# Uninstall with manual bundle ID (more accurate)
bash clean_uninstall.sh "Microsoft Excel" com.microsoft.Excel
```

---

### `clean_mac.sh` — macOS Storage Cleaner
Cleans macOS storage thoroughly with granular per-module control. Default mode: dry-run (safe).

**What gets cleaned:**
- System caches & logs (`~/Library/Caches`, `~/Library/Logs`)
- Saved Application State
- Container caches
- Electron app caches (Discord, WhatsApp, Signal, etc.)
- Zen browser caches (with protection for cookies, login, passwords, bookmarks)
- Steam caches (game data stays safe)
- Python `__pycache__` & `.pyc`
- Colima/Docker (`docker system prune`, builder, volumes)
- Time Machine snapshots (optional)

**Protected (never touched):**
- `~/.config`
- Zen: cookies, login state, passwords, bookmarks, IndexedDB

```bash
# Dry-run (default) — report only, nothing deleted
bash clean_mac.sh

# Actually execute
DRY_RUN=0 bash clean_mac.sh

# Custom: only clean Python caches, skip everything else
DRY_RUN=0 INCLUDE_PYTHON_CACHES=1 INCLUDE_SYSTEM_CACHES_LOGS=0 bash clean_mac.sh

# Thin Time Machine snapshots (requires sudo)
DRY_RUN=0 THIN_TM_SNAPSHOTS=1 bash clean_mac.sh
```

**Environment variables:**

| Variable | Default | Description |
|---|---|---|
| `DRY_RUN` | `1` | `0` = execute, `1` = simulate |
| `AGE_DAYS` | `7` | Delete files older than N days |
| `INCLUDE_SYSTEM_CACHES_LOGS` | `1` | System caches & logs |
| `INCLUDE_PYTHON_CACHES` | `1` | `__pycache__` & `.pyc` |
| `INCLUDE_COLIMA_PRUNE` | `1` | Docker/Colima prune |
| `INCLUDE_DEV_TOOL_CACHES` | `0` | brew cleanup, pip cache |
| `FORCE_RESET_COLIMA_VM` | `0` | Wipe entire Colima VM |
| `THIN_TM_SNAPSHOTS` | `0` | Thin Time Machine snapshots |
| `FORCE_DELETE_WUTHERING` | `0` | Delete Wuthering Waves data |

---

### `cleaner.sh` — Directory Size Viewer
Displays the size of every item at the first level of a folder, sorted from smallest to largest.

```bash
# View home directory sizes
bash cleaner.sh

# View sizes in a specific folder
bash cleaner.sh ~/Library
bash cleaner.sh ~/Library/Application\ Support
```

---

### `wa_cleaner.txt` — WhatsApp Full Wipe (Manual)
Commands to completely remove WhatsApp Desktop data (containers, group containers, caches, saved state). Useful when WhatsApp is misbehaving or for a clean reinstall.

> ⚠️ All local WhatsApp data will be deleted. Chat history is stored on servers, but local media will be lost.

```bash
bash -lc 'rm -rf ~/Library/Containers/net.whatsapp.WhatsApp/Data/*'
bash -lc 'rm -rf ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp/*'
bash -lc 'rm -rf ~/Library/Caches/net.whatsapp.WhatsApp*'
bash -lc 'rm -rf ~/Library/Saved\ Application\ State/net.whatsapp.WhatsApp.savedState'
```

---

## Setup

```bash
# Clone
git clone git@github.com:chairvus/mac-scripts.git
cd mac-scripts

# Make executable
chmod +x *.sh
```

---

## Tested on
- macOS (Apple Silicon)
- Fish shell / Bash
