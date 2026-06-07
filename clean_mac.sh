#!/bin/bash
# macOS Storage Cleaner — dioptimalkan untuk setup kamu:
#   Browser : Zen
#   Dev     : Python
#   Tools   : Docker/Colima, Steam, Discord, WhatsApp, Signal
#
# - NO TOUCH: ~/.config
# - NO TOUCH: data crucial Zen (cookies, login, IndexedDB, bookmarks, password)
# - Default DRY-RUN (aman) → set DRY_RUN=0 untuk eksekusi sungguhan
# DRY_RUN=0 bash mac_cleaner.sh (contoh command)

set -euo pipefail
IFS=$'\n\t'

# ===== Config =====
AGE_DAYS="${AGE_DAYS:-7}"
DRY_RUN="${DRY_RUN:-1}"           # 1=simulasi, 0=eksekusi sungguhan
VERBOSE="${VERBOSE:-1}"

# Modules (1=on, 0=off)
INCLUDE_SYSTEM_CACHES_LOGS="${INCLUDE_SYSTEM_CACHES_LOGS:-1}"
INCLUDE_SAVED_APP_STATE="${INCLUDE_SAVED_APP_STATE:-1}"
INCLUDE_CONTAINERS_CACHES="${INCLUDE_CONTAINERS_CACHES:-1}"
INCLUDE_ELECTRON_GENERIC="${INCLUDE_ELECTRON_GENERIC:-1}"
INCLUDE_BROWSERS_ZEN="${INCLUDE_BROWSERS_ZEN:-1}"
INCLUDE_STEAM_CACHES="${INCLUDE_STEAM_CACHES:-1}"
INCLUDE_DISCORD_CACHES="${INCLUDE_DISCORD_CACHES:-1}"
INCLUDE_WHATSAPP_CACHES="${INCLUDE_WHATSAPP_CACHES:-1}"
INCLUDE_SIGNAL_CACHES="${INCLUDE_SIGNAL_CACHES:-1}"
INCLUDE_PYTHON_CACHES="${INCLUDE_PYTHON_CACHES:-1}"
INCLUDE_DEV_TOOL_CACHES="${INCLUDE_DEV_TOOL_CACHES:-0}"

# Colima / Docker
INCLUDE_COLIMA_PRUNE="${INCLUDE_COLIMA_PRUNE:-1}"
FORCE_RESET_COLIMA_VM="${FORCE_RESET_COLIMA_VM:-0}"

# Time Machine
INCLUDE_TM_SNAPSHOT_REPORT="${INCLUDE_TM_SNAPSHOT_REPORT:-1}"
THIN_TM_SNAPSHOTS="${THIN_TM_SNAPSHOTS:-0}"
THIN_TM_BYTES="${THIN_TM_BYTES:-20000000000}"

# Games
INCLUDE_GAMES="${INCLUDE_GAMES:-1}"
FORCE_DELETE_WUTHERING="${FORCE_DELETE_WUTHERING:-0}"

# Reporting
REPORT_TOP_BIG_HOME="${REPORT_TOP_BIG_HOME:-1}"
REPORT_BIG_FILES_GB="${REPORT_BIG_FILES_GB:-2}"

# ===== Utils =====
title() { echo; echo "==== $* ===="; }
log()   { [ "$VERBOSE" = "1" ] && echo "$*" || true; }
have()  { command -v "$1" >/dev/null 2>&1; }

DEL_CMD="rm -rf"
if have trash; then DEL_CMD="trash -F"; fi

section_report() {
  local label="$1"; shift
  local total_kb=0
  for p in "$@"; do
    [ -e "$p" ] || continue
    local s
    s=$(du -sk "$p" 2>/dev/null | cut -f1 || echo 0)
    total_kb=$((total_kb + s))
  done
  echo "  📦 $label — ukuran sekarang: $(echo $total_kb | awk '{printf "%.1f MB", $1/1024}')"
}

delete_path() {
  local p="$1"
  [ -e "$p" ] || return 0
  case "$p" in
    "$HOME/.config"* )
      echo "⛔ SKIP (protected): $p"
      return 0
      ;;
  esac
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY-RUN] would delete: $p"
  else
    $DEL_CMD "$p" 2>/dev/null || true
  fi
}

delete_old_in() {
  local root="$1"
  [ -d "$root" ] || return 0
  case "$root" in
    "$HOME/.config"* )
      echo "⛔ SKIP (protected): $root"
      return 0
      ;;
  esac
  if [ "$DRY_RUN" = "1" ]; then
    local count
    count=$(find "$root" -type f -mtime +"$AGE_DAYS" 2>/dev/null | wc -l | tr -d ' ')
    log "[DRY-RUN] $root → $count file akan dihapus"
  else
    while IFS= read -r f; do
      $DEL_CMD "$f" 2>/dev/null || true
    done < <(find "$root" -type f -mtime +"$AGE_DAYS" -print 2>/dev/null)
  fi
}

clean_glob_list() {
  for p in "$@"; do
    delete_old_in "$p"
  done
}

clean_named_dirs_in() {
  local root="$1"; shift || true
  [ -d "$root" ] || return 0
  case "$root" in
    "$HOME/.config"* )
      echo "⛔ SKIP (protected): $root"
      return 0
      ;;
  esac
  while IFS= read -r d; do delete_old_in "$d"; done < <(
    find "$root" -type d \( $(printf -- '-name %q -o ' "$@") -false \) 2>/dev/null
  )
}

warn_full_disk_access() {
  if ! ls "$HOME/Library/Mail" >/dev/null 2>&1; then
    echo "⚠️  Untuk visibilitas lebih lengkap, beri Terminal Full Disk Access:"
    echo "   System Settings → Privacy & Security → Full Disk Access"
  fi
}

warn_sudo_needed() {
  [ "$THIN_TM_SNAPSHOTS" = "1" ] || return 0
  echo ""
  echo "⚠️  THIN_TM_SNAPSHOTS=1 membutuhkan sudo — kamu mungkin diminta password."
  echo ""
}

# ===== Reporting =====
report_storage_overview() {
  title "Storage overview"
  df -h || true
}

report_home_sizes() {
  title "Top-level sizes in ~ (largest 25)"
  du -h -d 1 "$HOME" 2>/dev/null | sort -h | tail -n 25 || true

  title "Top ~/Library (largest 25)"
  du -h -d 1 "$HOME/Library" 2>/dev/null | sort -h | tail -n 25 || true

  title "Top ~/Library/Application Support (largest 30)"
  du -h -d 2 "$HOME/Library/Application Support" 2>/dev/null | sort -h | tail -n 30 || true

  title "Top ~/Library/Containers (largest 30)"
  du -h -d 2 "$HOME/Library/Containers" 2>/dev/null | sort -h | tail -n 30 || true
}

report_big_files_in_home() {
  [ "$REPORT_TOP_BIG_HOME" = "1" ] || return 0
  title "File besar di ~ (>= ${REPORT_BIG_FILES_GB}GiB) [report only]"
  find "$HOME" \
    -path "$HOME/.config" -prune -o \
    -type f -size +"${REPORT_BIG_FILES_GB}"G -print 2>/dev/null | head -n 60 || true
}

# ===== System =====
clean_system() {
  [ "$INCLUDE_SYSTEM_CACHES_LOGS" = "1" ] || { title "Skip System caches/logs"; return 0; }
  title "System: ~/Library/{Caches,Logs} (> ${AGE_DAYS} hari)"
  section_report "Caches+Logs" "$HOME/Library/Caches" "$HOME/Library/Logs"
  delete_old_in "$HOME/Library/Caches"
  delete_old_in "$HOME/Library/Logs"
  title "Quick Look thumbnail cache"
  if [ "$DRY_RUN" = "1" ]; then
    log "[DRY-RUN] qlmanage -r cache"
  else
    qlmanage -r cache >/dev/null 2>&1 || true
  fi
}

clean_saved_state() {
  [ "$INCLUDE_SAVED_APP_STATE" = "1" ] || { title "Skip Saved Application State"; return 0; }
  title "Saved Application State (> ${AGE_DAYS} hari)"
  section_report "Saved State" "$HOME/Library/Saved Application State"
  delete_old_in "$HOME/Library/Saved Application State"
}

clean_containers() {
  [ "$INCLUDE_CONTAINERS_CACHES" = "1" ] || { title "Skip Containers caches/logs"; return 0; }
  title "Containers Data/Library/{Caches,Logs} (> ${AGE_DAYS} hari)"
  while IFS= read -r d; do delete_old_in "$d"; done < <(
    find "$HOME/Library/Containers" -maxdepth 3 -type d \
      \( -name Caches -o -name Logs \) -path "*/Data/Library/*" 2>/dev/null
  )
}

clean_electron_generic() {
  [ "$INCLUDE_ELECTRON_GENERIC" = "1" ] || { title "Skip Electron generic caches"; return 0; }
  title "Electron generic caches (> ${AGE_DAYS} hari)"
  local root="$HOME/Library/Application Support"
  while IFS= read -r appdir; do
    # ✅ Skip folder Zen — ditangani terpisah dengan perlindungan khusus
    case "$appdir" in
      *"/zen"*|*"/Zen"* ) continue ;;
    esac
    clean_named_dirs_in "$appdir" "Cache" "Caches" "Code Cache" "GPUCache"
    clean_glob_list \
      "$appdir/Service Worker/CacheStorage" \
      "$appdir/Service Worker/ScriptCache" \
      "$appdir/Partitions/Default/Cache" \
      "$appdir/Partitions/Default/Code Cache" \
      "$appdir/Partitions/Default/GPUCache"
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
}

# ===== ✅ Zen Browser — dengan perlindungan data crucial =====
clean_zen() {
  [ "$INCLUDE_BROWSERS_ZEN" = "1" ] || { title "Skip Zen browser"; return 0; }
  title "Zen browser caches (> ${AGE_DAYS} hari)"

  # ✅ FIX: resolve symlink untuk cegah double-delete
  local seen_real=""
  local bases=(
    "$HOME/Library/Application Support/zen/Profiles"
    "$HOME/Library/Application Support/Zen/Profiles"
  )

  for base in "${bases[@]}"; do
    [ -d "$base" ] || continue

    # resolve path asli (ikuti symlink)
    local real_base
    real_base=$(realpath "$base" 2>/dev/null || echo "$base")

    # skip kalau sudah diproses
    if echo "$seen_real" | grep -qF "$real_base"; then
      log "ℹ️  Skip duplikat (symlink): $base → $real_base"
      continue
    fi
    seen_real="$seen_real $real_base"

    log "➤ $base"
    section_report "Zen" "$base"

    while IFS= read -r profile_dir; do
      # ✅ HANYA hapus folder cache yang benar-benar aman:
      delete_old_in "$profile_dir/cache2"           # HTTP cache
      delete_old_in "$profile_dir/startupCache"     # cache startup
      delete_old_in "$profile_dir/thumbnails"       # thumbnail tab
      delete_old_in "$profile_dir/safebrowsing"     # DB phishing (auto-rebuild)
      delete_old_in "$profile_dir/shader-cache"     # GPU shader cache

      # ⛔ TIDAK DISENTUH (data crucial):
      # storage/default   → IndexedDB, login state, app data website
      # storage/permanent → data permanen
      # cookies.sqlite    → cookies & sesi login
      # places.sqlite     → history & bookmarks
      # key4.db           → enkripsi password
      # logins.json       → saved passwords
      # sessionstore.jsonlz4 → tabs & sesi terakhir

    done < <(find "$real_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  done
}

# ===== Steam =====
clean_steam() {
  [ "$INCLUDE_STEAM_CACHES" = "1" ] || { title "Skip Steam"; return 0; }
  title "Steam caches (> ${AGE_DAYS} hari)"
  local base="$HOME/Library/Application Support/Steam"
  [ -d "$base" ] || { echo "ℹ️  Steam tidak ditemukan."; return 0; }
  section_report "Steam" "$base/appcache" "$base/depotcache" "$base/httpcache" "$base/steamhtmlcache" "$base/shadercache"
  clean_glob_list \
    "$base/appcache" \
    "$base/depotcache" \
    "$base/httpcache" \
    "$base/steamhtmlcache" \
    "$base/shadercache"
  echo "ℹ️  Tidak disentuh: steamapps (game kamu aman)"
}

# ===== Discord =====
clean_discord() {
  [ "$INCLUDE_DISCORD_CACHES" = "1" ] || { title "Skip Discord"; return 0; }
  title "Discord caches (> ${AGE_DAYS} hari)"
  local base="$HOME/Library/Application Support/discord"
  [ -d "$base" ] || { echo "ℹ️  Discord tidak ditemukan."; return 0; }
  section_report "Discord" "$base/Cache" "$base/Code Cache" "$base/GPUCache"
  clean_glob_list \
    "$base/Cache" \
    "$base/Code Cache" \
    "$base/GPUCache" \
    "$base/Service Worker/CacheStorage"
}

# ===== WhatsApp =====
clean_whatsapp() {
  [ "$INCLUDE_WHATSAPP_CACHES" = "1" ] || { title "Skip WhatsApp"; return 0; }
  title "WhatsApp caches (> ${AGE_DAYS} hari)"
  local base="$HOME/Library/Application Support/WhatsApp"
  [ -d "$base" ] || { echo "ℹ️  WhatsApp tidak ditemukan."; return 0; }
  section_report "WhatsApp" "$base/Cache" "$base/Code Cache" "$base/GPUCache"
  clean_glob_list \
    "$base/Cache" \
    "$base/Code Cache" \
    "$base/GPUCache" \
    "$base/Service Worker/CacheStorage"
}

# ===== Signal =====
clean_signal() {
  [ "$INCLUDE_SIGNAL_CACHES" = "1" ] || { title "Skip Signal"; return 0; }
  title "Signal caches (> ${AGE_DAYS} hari)"
  local base="$HOME/Library/Application Support/Signal"
  [ -d "$base" ] || { echo "ℹ️  Signal tidak ditemukan."; return 0; }
  section_report "Signal" "$base/Cache" "$base/Code Cache" "$base/GPUCache"
  clean_glob_list \
    "$base/Cache" \
    "$base/Code Cache" \
    "$base/GPUCache" \
    "$base/Service Worker/CacheStorage"
}

# ===== Python =====
clean_python() {
  [ "$INCLUDE_PYTHON_CACHES" = "1" ] || { title "Skip Python caches"; return 0; }
  title "Python __pycache__ & .pyc (> ${AGE_DAYS} hari)"
  if [ "$DRY_RUN" = "1" ]; then
    local count_dir count_pyc
    count_dir=$(find "$HOME" -path "$HOME/.config" -prune -o -type d -name "__pycache__" -print 2>/dev/null | wc -l | tr -d ' ')
    count_pyc=$(find "$HOME" -path "$HOME/.config" -prune -o -type f -name "*.pyc" -print 2>/dev/null | wc -l | tr -d ' ')
    log "[DRY-RUN] Akan hapus $count_dir folder __pycache__ dan $count_pyc file .pyc"
  else
    find "$HOME" \
      -path "$HOME/.config" -prune -o \
      -type d -name "__pycache__" -exec $DEL_CMD {} + 2>/dev/null || true
    find "$HOME" \
      -path "$HOME/.config" -prune -o \
      -type f -name "*.pyc" -exec $DEL_CMD {} + 2>/dev/null || true
    echo "✅ __pycache__ dan .pyc dihapus."
  fi
}

# ===== Dev tools (opt-in) =====
clean_dev_tools() {
  [ "$INCLUDE_DEV_TOOL_CACHES" = "1" ] || { title "Skip dev tool caches (set INCLUDE_DEV_TOOL_CACHES=1)"; return 0; }
  title "Dev tool caches (brew, pip)"
  if [ "$DRY_RUN" = "1" ]; then
    have brew && log "[DRY-RUN] brew cleanup -s"
    have pip  && log "[DRY-RUN] pip cache purge"
  else
    have brew && (brew cleanup -s || true; rm -rf "$HOME/Library/Caches/Homebrew" || true)
    have pip  && (pip cache purge || true)
  fi
}

# ===== Games =====
handle_big_games() {
  [ "$INCLUDE_GAMES" = "1" ] || { title "Skip game containers"; return 0; }
  local ww="$HOME/Library/Containers/com.kurogame.wutheringwaves.global"
  if [ -d "$ww" ]; then
    title "Terdeteksi: Wuthering Waves"
    section_report "Wuthering Waves" "$ww"
    if [ "$FORCE_DELETE_WUTHERING" = "1" ]; then
      echo "⚠️  Menghapus Wuthering Waves data..."
      delete_path "$ww"
    else
      echo "ℹ️  Untuk hapus: set FORCE_DELETE_WUTHERING=1"
    fi
  fi
}

# ===== Time Machine =====
handle_tm_snapshots() {
  [ "$INCLUDE_TM_SNAPSHOT_REPORT" = "1" ] || { title "Skip Time Machine"; return 0; }
  title "Time Machine local snapshots (report)"
  if have tmutil; then
    tmutil listlocalsnapshots / 2>/dev/null || echo "(tidak ada)"
  fi
  if [ "$THIN_TM_SNAPSHOTS" = "1" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      log "[DRY-RUN] sudo tmutil thinlocalsnapshots / $THIN_TM_BYTES 4"
    else
      sudo tmutil thinlocalsnapshots / "$THIN_TM_BYTES" 4 || true
    fi
  else
    echo "ℹ️  Untuk thin: set THIN_TM_SNAPSHOTS=1 (perlu sudo)"
  fi
}

# ===== Colima / Docker =====
handle_colima() {
  [ "$INCLUDE_COLIMA_PRUNE" = "1" ] || { title "Skip Colima/Docker"; return 0; }
  if [ ! -d "$HOME/.colima" ]; then
    title "Colima tidak terdeteksi"
    return 0
  fi
  title "Colima / Docker cleanup"
  section_report "Colima" "$HOME/.colima"

  if ! have colima; then
    echo "ℹ️  colima command tidak ditemukan."
    return 0
  fi

  local colima_running=0
  colima status >/dev/null 2>&1 && colima_running=1 || true

  if [ "$colima_running" = "0" ]; then
    echo "ℹ️  Colima sedang tidak berjalan — skip docker prune."
    echo "    Jalankan colima dulu jika ingin bersihkan Docker data."
  else
    if [ "$DRY_RUN" = "1" ]; then
      log "[DRY-RUN] docker system prune -af"
      log "[DRY-RUN] docker builder prune -af"
      log "[DRY-RUN] docker volume prune -f"
    else
      docker system prune -af || true
      docker builder prune -af || true
      docker volume prune -f || true
    fi
  fi

  if [ "$FORCE_RESET_COLIMA_VM" = "1" ]; then
    title "⚠️  RESET Colima VM — semua image & volume akan hilang!"
    if [ "$DRY_RUN" = "1" ]; then
      log "[DRY-RUN] colima stop && colima delete -f"
    else
      colima stop || true
      colima delete -f || true
    fi
  else
    echo "ℹ️  Untuk wipe VM: set FORCE_RESET_COLIMA_VM=1 (BERBAHAYA)"
  fi

  title "Colima size setelah operasi"
  du -sh "$HOME/.colima" 2>/dev/null || true
}

# ===== Main =====
echo "=========================================="
echo "🧹 macOS Storage Cleaner"
echo "   Setup: Zen · Python · Docker · Steam · Discord · WhatsApp · Signal"
echo "   AGE_DAYS=$AGE_DAYS  DRY_RUN=$DRY_RUN"
echo "   ⛔ DILINDUNGI: ~/.config, Zen cookies/login/passwords/bookmarks"
if [ "$DRY_RUN" = "1" ]; then
  echo "   🔍 MODE: DRY-RUN — tidak ada yang dihapus"
  echo "   💡 Eksekusi: env DRY_RUN=0 bash mac_cleaner.sh"
else
  echo "   ⚡ MODE: EKSEKUSI — file akan dihapus!"
fi
echo "=========================================="

warn_full_disk_access
warn_sudo_needed

report_storage_overview
report_home_sizes
report_big_files_in_home

title "📊 Disk sebelum bersih-bersih"
df -h || true

clean_system
clean_saved_state
clean_containers
clean_electron_generic
clean_zen
clean_steam
clean_discord
clean_whatsapp
clean_signal
clean_python
clean_dev_tools
handle_big_games
handle_tm_snapshots
handle_colima

echo
echo "=========================================="
echo "✅ Selesai. (DRY_RUN=$DRY_RUN)"
echo "=========================================="

title "📊 Disk sesudah bersih-bersih"
df -h || true
