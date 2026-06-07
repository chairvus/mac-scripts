# mac-scripts 🧹

Kumpulan bash scripts untuk maintenance & cleanup macOS.

---

## Scripts

### `clean_uninstall.sh` — Clean Uninstall App
Hapus app beserta semua file sisa (containers, caches, preferences, defaults database, dll) secara menyeluruh.

**Fitur:**
- Auto-detect bundle ID dari app
- Pakai `mdfind` untuk lacak semua file terkait app (lebih akurat dari AppCleaner)
- Scan: Containers, Group Containers, App Support, Caches, Logs, Preferences, LaunchAgents, Saved State, HTTPStorages, WebKit, `/private/var/folders`, defaults database
- Kill app otomatis sebelum uninstall
- Dry-run mode (preview tanpa hapus)
- Deduplikasi hasil
- Handle system-level files dengan sudo terpisah

```bash
# Preview dulu (aman)
bash clean_uninstall.sh "Spotify" --dry-run

# Hapus dengan auto-detect bundle ID
bash clean_uninstall.sh "Spotify"

# Hapus dengan bundle ID manual (lebih akurat)
bash clean_uninstall.sh "Microsoft Excel" com.microsoft.Excel
```

---

### `clean_mac.sh` — macOS Storage Cleaner
Bersihkan storage macOS secara menyeluruh dengan kontrol granular per-modul. Default mode: dry-run (aman).

**Yang dibersihkan:**
- System caches & logs (`~/Library/Caches`, `~/Library/Logs`)
- Saved Application State
- Container caches
- Electron app caches (Discord, WhatsApp, Signal, dll)
- Zen browser caches (dengan proteksi cookies, login, passwords, bookmarks)
- Steam caches (game data aman)
- Python `__pycache__` & `.pyc`
- Colima/Docker (`docker system prune`, builder, volumes)
- Time Machine snapshots (opsional)

**Dilindungi (tidak disentuh):**
- `~/.config`
- Zen: cookies, login state, passwords, bookmarks, IndexedDB

```bash
# Dry-run (default) — hanya laporan, tidak hapus
bash clean_mac.sh

# Eksekusi sungguhan
DRY_RUN=0 bash clean_mac.sh

# Custom: hanya bersihkan Python caches, skip yang lain
DRY_RUN=0 INCLUDE_PYTHON_CACHES=1 INCLUDE_SYSTEM_CACHES_LOGS=0 bash clean_mac.sh

# Thin Time Machine snapshots (perlu sudo)
DRY_RUN=0 THIN_TM_SNAPSHOTS=1 bash clean_mac.sh
```

**Environment variables:**

| Variable | Default | Keterangan |
|---|---|---|
| `DRY_RUN` | `1` | `0` = eksekusi, `1` = simulasi |
| `AGE_DAYS` | `7` | Hapus file lebih tua dari N hari |
| `INCLUDE_SYSTEM_CACHES_LOGS` | `1` | System caches & logs |
| `INCLUDE_PYTHON_CACHES` | `1` | `__pycache__` & `.pyc` |
| `INCLUDE_COLIMA_PRUNE` | `1` | Docker/Colima prune |
| `INCLUDE_DEV_TOOL_CACHES` | `0` | brew cleanup, pip cache |
| `FORCE_RESET_COLIMA_VM` | `0` | Wipe seluruh Colima VM |
| `THIN_TM_SNAPSHOTS` | `0` | Thin Time Machine snapshots |
| `FORCE_DELETE_WUTHERING` | `0` | Hapus Wuthering Waves data |

---

### `cleaner.sh` — Directory Size Viewer
Tampilkan ukuran setiap item di level pertama suatu folder, diurutkan dari terkecil ke terbesar.

```bash
# Lihat ukuran isi home directory
bash cleaner.sh

# Lihat ukuran isi folder tertentu
bash cleaner.sh ~/Library
bash cleaner.sh ~/Library/Application\ Support
```

---

### `wa_cleaner.txt` — WhatsApp Full Wipe (Manual)
Command untuk hapus total data WhatsApp Desktop (containers, group containers, caches, saved state). Berguna kalau WhatsApp bermasalah atau mau reinstall bersih.

> ⚠️ Semua data lokal WhatsApp akan terhapus. Chat history tersimpan di server, tapi media lokal hilang.

```bash
# Copy-paste command dari wa_cleaner.txt, atau:
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

# Kasih permission
chmod +x *.sh
```

---

## Tested on
- macOS (Apple Silicon)
- Fish shell / Bash
