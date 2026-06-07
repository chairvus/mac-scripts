#!/bin/bash
# Tampilkan ukuran setiap item (file/folder) di level-1 lalu urutkan human-readable
# Default folder = HOME (~) kalau tidak diberi argumen

TARGET_DIR="${1:-$HOME}"

echo "📦 Ukuran isi level-1: $TARGET_DIR"
# Cetak semua entri level-1 (termasuk yang ada spasi & hidden files), lalu hitung size & sort
find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print0 \
  | xargs -0 du -sh 2>/dev/null \
  | sort -h
