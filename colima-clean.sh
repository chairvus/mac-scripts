#!/usr/bin/env bash
set -Eeuo pipefail

# Opsi lingkungan:
#   DRY_RUN=1        -> simulasi (tidak benar-benar menghapus)
#   COLIMA_TRIM=1    -> jalankan colima prune setelah pembersihan

DRY_RUN=${DRY_RUN:-0}
COLIMA_TRIM=${COLIMA_TRIM:-0}

run() {
  if [[ "$DRY_RUN" = "1" ]]; then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

echo "🧹 Bersih-bersih Colima/Docker (AMAN untuk data di named volumes)..."
echo "   options => DRY_RUN=$DRY_RUN COLIMA_TRIM=$COLIMA_TRIM"

# Ringkasan sebelum
echo "ℹ️  Sebelum:"
docker system df || true

# 1) Hapus container mati
echo "➡️  Menghapus container mati..."
run "docker container prune -f"

# 2) Hapus dangling images
echo "➡️  Menghapus dangling images..."
run "docker image prune -f"

# 3) Hapus network tidak terpakai
echo "➡️  Menghapus network tidak terpakai..."
run "docker network prune -f"

# ⚠️ JANGAN hapus volume di opsi A aman (hindari kehilangan data)
# (Baris ini DIHAPUS dari script lama)
# docker volume prune -f

# 4) Bersihkan image yang tidak dipakai sama sekali
echo "➡️  Menghapus semua image tidak terpakai (bukan hanya dangling)..."
run "docker image prune -a -f"

# 5) Bersihkan build cache
echo "➡️  Menghapus build cache..."
run "docker builder prune -a -f"

# 6) Prune level sistem (tanpa volume!)
echo "➡️  System prune (tanpa volume)..."
run "docker system prune -a -f"

# 7) Ringkasan sesudah
echo "✅ Sesudah Docker-side:"
docker system df || true

echo "📦 Container aktif:"
docker ps

echo "🖼️  Image tersisa:"
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}'

# 8) (Opsional) Trim disk VM Colima agar ruang di host benar-benar balik
if [[ "$COLIMA_TRIM" = "1" && "$(command -v colima || true)" != "" ]]; then
  echo "🧽 Colima trim disk..."
  run "colima stop"
  run "colima prune -f"
  run "colima start"
fi

echo "🎉 Selesai."
