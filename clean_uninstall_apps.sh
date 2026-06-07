#!/bin/bash

# ============================================================
#  clean_uninstall.sh — Clean uninstall apps on macOS
#  Usage:
#    bash clean_uninstall.sh "App Name"
#    bash clean_uninstall.sh "App Name" com.bundle.id
#    bash clean_uninstall.sh "App Name" --dry-run
#    bash clean_uninstall.sh "App Name" com.bundle.id --dry-run
# ============================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# --- Parse args ---
APP_NAME=""
BUNDLE_ID=""
DRY_RUN=false

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  elif [[ -z "$APP_NAME" ]]; then
    APP_NAME="$arg"
  elif [[ -z "$BUNDLE_ID" ]]; then
    BUNDLE_ID="$arg"
  fi
done

if [[ -z "$APP_NAME" ]]; then
  echo -e "${BOLD}Usage:${NC}"
  echo -e "  bash clean_uninstall.sh \"App Name\""
  echo -e "  bash clean_uninstall.sh \"App Name\" com.bundle.id"
  echo -e "  bash clean_uninstall.sh \"App Name\" --dry-run"
  exit 1
fi

APP_PATH="/Applications/${APP_NAME}.app"

echo -e "\n${BOLD}${CYAN}=== Clean Uninstall: ${APP_NAME} ===${NC}"
$DRY_RUN && echo -e "${YELLOW}[DRY RUN — tidak ada yang dihapus]${NC}"
echo ""

# --- Kill app if running ---
if pgrep -xi "$APP_NAME" &>/dev/null; then
  echo -e "${YELLOW}⚠ App sedang berjalan. Menutup...${NC}"
  if ! $DRY_RUN; then
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || pkill -xi "$APP_NAME" 2>/dev/null || true
    sleep 2
  fi
fi

# --- Auto-detect bundle ID ---
if [[ -z "$BUNDLE_ID" ]]; then
  if [[ -d "$APP_PATH" ]]; then
    BUNDLE_ID=$(defaults read "${APP_PATH}/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
    [[ -n "$BUNDLE_ID" ]] && echo -e "${GREEN}✓ Bundle ID: ${BUNDLE_ID}${NC}" \
                          || echo -e "${YELLOW}⚠ Bundle ID tidak terdeteksi. Pencarian pakai nama.${NC}"
  else
    echo -e "${YELLOW}⚠ App tidak ditemukan di /Applications. Lanjut bersihkan sisa file...${NC}"
  fi
fi

# --- Short name fallback (for folder-name matching) ---
SHORT_NAME=$(echo "$BUNDLE_ID" | awk -F. '{print $2}' | tr '[:upper:]' '[:lower:]')
[[ -z "$SHORT_NAME" ]] && SHORT_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')

# -------------------------------------------------------
# COLLECT PATHS
# -------------------------------------------------------
declare -A SEEN   # deduplicate
USER_PATHS=()
SYS_PATHS=()

add_path() {
  local p="$1"
  local target_array="$2"
  # Normalize path
  p="${p%/}"
  [[ -z "$p" ]] && return
  [[ -n "${SEEN[$p]}" ]] && return
  SEEN["$p"]=1
  if [[ "$target_array" == "sys" ]]; then
    SYS_PATHS+=("$p")
  else
    USER_PATHS+=("$p")
  fi
}

# 1. App bundle
[[ -d "$APP_PATH" ]] && add_path "$APP_PATH" user

# 2. mdfind by bundle ID (most accurate — finds files macOS tracks)
if [[ -n "$BUNDLE_ID" ]]; then
  while IFS= read -r p; do
    add_path "$p" user
  done < <(mdfind "kMDItemCFBundleIdentifier == '${BUNDLE_ID}'" 2>/dev/null)
fi

# 3. Standard Library locations — by bundle ID prefix & short name
SCAN_DIRS=(
  ~/Library/Containers
  ~/Library/Group\ Containers
  ~/Library/Application\ Support
  ~/Library/Caches
  ~/Library/Logs
  ~/Library/Preferences
  ~/Library/LaunchAgents
  ~/Library/Saved\ Application\ State
  ~/Library/HTTPStorages
  ~/Library/WebKit
)

for dir in "${SCAN_DIRS[@]}"; do
  [[ ! -d "$dir" ]] && continue
  # Match by bundle ID
  if [[ -n "$BUNDLE_ID" ]]; then
    while IFS= read -r p; do add_path "$p" user; done \
      < <(find "$dir" -maxdepth 1 -iname "*${BUNDLE_ID}*" 2>/dev/null)
  fi
  # Match by short name
  while IFS= read -r p; do add_path "$p" user; done \
    < <(find "$dir" -maxdepth 1 -iname "*${SHORT_NAME}*" 2>/dev/null)
done

# 4. System-level (needs sudo)
SYS_SCAN_DIRS=(
  /Library/LaunchAgents
  /Library/LaunchDaemons
  /Library/Application\ Support
  /Library/Preferences
)

for dir in "${SYS_SCAN_DIRS[@]}"; do
  [[ ! -d "$dir" ]] && continue
  if [[ -n "$BUNDLE_ID" ]]; then
    while IFS= read -r p; do add_path "$p" sys; done \
      < <(find "$dir" -maxdepth 1 -iname "*${BUNDLE_ID}*" 2>/dev/null)
  fi
  while IFS= read -r p; do add_path "$p" sys; done \
    < <(find "$dir" -maxdepth 1 -iname "*${SHORT_NAME}*" 2>/dev/null)
done

# 5. /private/var/folders temp files (via mdfind)
if [[ -n "$BUNDLE_ID" ]]; then
  while IFS= read -r p; do
    [[ "$p" == /private/var/folders/* ]] && add_path "$p" user
  done < <(mdfind -onlyin /private/var/folders "kMDItemCFBundleIdentifier == '${BUNDLE_ID}'" 2>/dev/null)
fi

# -------------------------------------------------------
# PREVIEW
# -------------------------------------------------------
TOTAL_FOUND=$(( ${#USER_PATHS[@]} + ${#SYS_PATHS[@]} ))

if [[ $TOTAL_FOUND -eq 0 ]]; then
  echo -e "${GREEN}✓ Tidak ada file ditemukan untuk \"${APP_NAME}\". Sudah bersih!${NC}\n"
  exit 0
fi

echo -e "${BOLD}File/folder yang akan dihapus:${NC}\n"

TOTAL_SIZE=0
if [[ ${#USER_PATHS[@]} -gt 0 ]]; then
  echo -e "${CYAN}User-level:${NC}"
  for p in "${USER_PATHS[@]}"; do
    SIZE=$(du -sh "$p" 2>/dev/null | cut -f1)
    echo -e "  ${RED}✗${NC} $p ${DIM}(${SIZE})${NC}"
  done
fi

if [[ ${#SYS_PATHS[@]} -gt 0 ]]; then
  echo -e "\n${CYAN}System-level (butuh sudo):${NC}"
  for p in "${SYS_PATHS[@]}"; do
    SIZE=$(du -sh "$p" 2>/dev/null | cut -f1)
    echo -e "  ${RED}✗${NC} $p ${DIM}(${SIZE})${NC}"
  done
fi

echo ""

# --- Dry run: preview defaults database ---
if $DRY_RUN; then
  if [[ -n "$BUNDLE_ID" ]]; then
    MATCHED_DOMAINS=$(defaults domains 2>/dev/null | tr ',' '\n' | tr -d ' ' | grep -i "$BUNDLE_ID" || true)
    if [[ -n "$MATCHED_DOMAINS" ]]; then
      echo -e "${CYAN}Defaults database entries (akan dihapus):${NC}"
      while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        echo -e "  ${RED}✗${NC} $domain"
      done <<< "$MATCHED_DOMAINS"
      echo ""
    fi
  fi
  echo -e "${YELLOW}[DRY RUN] Selesai. Jalankan tanpa --dry-run untuk hapus beneran.${NC}\n"
  exit 0
fi

# -------------------------------------------------------
# CONFIRM & DELETE
# -------------------------------------------------------
read -rp "$(echo -e ${BOLD}"Hapus semua? [y/N]: "${NC})" CONFIRM
[[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && echo -e "${YELLOW}Dibatalkan.${NC}\n" && exit 0

echo ""

# Delete user-level
for p in "${USER_PATHS[@]}"; do
  if rm -rf "$p" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $p"
  else
    echo -e "  ${RED}✗ Gagal:${NC} $p"
  fi
done

# Delete system-level
if [[ ${#SYS_PATHS[@]} -gt 0 ]]; then
  echo ""
  read -rp "$(echo -e ${BOLD}"Hapus system-level files dengan sudo? [y/N]: "${NC})" SUDO_CONFIRM
  if [[ "$SUDO_CONFIRM" == "y" || "$SUDO_CONFIRM" == "Y" ]]; then
    for p in "${SYS_PATHS[@]}"; do
      if sudo rm -rf "$p" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $p"
      else
        echo -e "  ${RED}✗ Gagal:${NC} $p"
      fi
    done
  fi
fi

# --- Clear defaults database ---
if [[ -n "$BUNDLE_ID" ]]; then
  echo ""
  # Check all matching domains (app bisa punya beberapa domain, e.g. com.microsoft.Excel + com.microsoft.Excel.plist)
  MATCHED_DOMAINS=$(defaults domains 2>/dev/null | tr ',' '\n' | tr -d ' ' | grep -i "$BUNDLE_ID" || true)
  if [[ -n "$MATCHED_DOMAINS" ]]; then
    echo -e "${CYAN}Defaults database entries:${NC}"
    while IFS= read -r domain; do
      [[ -z "$domain" ]] && continue
      if defaults delete "$domain" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Cleared defaults:${NC} $domain"
      else
        echo -e "  ${YELLOW}⚠ Tidak bisa hapus defaults:${NC} $domain"
      fi
    done <<< "$MATCHED_DOMAINS"
  else
    echo -e "${DIM}ℹ Tidak ada defaults database entry untuk ${BUNDLE_ID}${NC}"
  fi
fi

echo -e "\n${GREEN}${BOLD}✓ Done! \"${APP_NAME}\" sudah clean uninstall.${NC}\n"
