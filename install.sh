#!/usr/bin/env bash
# NixOS otomatik kurulum (UEFI + M.2 NVMe)
# Kullanim:  sudo DISK=/dev/nvme0n1 bash install.sh
# Not: Calistirdigin disk TAMAMEN SILINIR.
set -euo pipefail

DISK="${DISK:-/dev/nvme0n1}"
HOST_CFG="nixos"
MNT=/mnt
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

# ---- on kontroller ----
[[ $EUID -eq 0 ]] || die "root olarak calistir (sudo ...)."
[[ -d /sys/firmware/efi ]] || die "Sistem UEFI modunda degil. BIOS'ta UEFI'yi ac."
[[ -b "$DISK" ]] || die "Disk bulunamadi: $DISK"

for c in sgdisk mkfs.fat mkfs.ext4 git nixos-generate-config nixos-install; do
  command -v "$c" >/dev/null 2>&1 || die "Gerekli komut yok: $c"
done

for f in flake.nix configuration.nix home.nix; do
  [[ -f "$REPO_DIR/$f" ]] || die "$REPO_DIR/$f bulunamadi."
done

# ---- internet uyarisi ----
if ! ping -c1 -W3 nixos.org >/dev/null 2>&1; then
  log "UYARI: Internet yok gibi. nixos-install paketleri indiremez ve basarisiz olur."
fi

# ---- disk dogrulama ----
log "Disk bilgisi: $DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK" || true
echo
read -rp "!! $DISK TAMAMEN SILINECEK. Devam icin 'SIL' yaz: " ans
[[ "$ans" == "SIL" ]] || die "Iptal edildi."

# ---- bolum adi eki (nvme/mmc -> p) ----
if [[ "$DISK" =~ [0-9]$ ]]; then SUF=p; else SUF=""; fi
ESP="${DISK}${SUF}1"
ROOT="${DISK}${SUF}2"

# ---- mevcut mount/swap kapat ----
log "Olasi mount/swap kapatiliyor"
umount -R "$MNT" 2>/dev/null || true
swapoff -a 2>/dev/null || true

# ---- bolumleme ----
log "Bolumleme (sgdisk)"
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n 1:1MiB:512MiB -t 1:ef00 -c 1:ESP   "$DISK"
sgdisk -n 2:512MiB:0    -t 2:8300 -c 2:nixos "$DISK"
if command -v partprobe >/dev/null 2>&1; then
  partprobe "$DISK"
else
  blockdev --rereadpt "$DISK" || true
fi
udevadm settle
sgdisk -p "$DISK"

# ---- format ----
log "Format"
mkfs.fat -F32 "$ESP"
mkfs.ext4 -F "$ROOT"

# ---- mount ----
log "Mount"
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot"
mount "$ESP" "$MNT/boot"

# ---- donanim yapilandirmasi ----
log "Donanim yapilandirmasi uretiliyor (nixos-generate-config)"
nixos-generate-config --root "$MNT"

# ---- repo dosyalarini kopyala (mevcut script dizininden) ----
log "Config dosyalari $MNT/etc/nixos'a kopyalaniyor"
mkdir -p "$MNT/etc/nixos"
shopt -s dotglob nullglob
for f in "$REPO_DIR"/*; do
  base="$(basename "$f")"
  [[ "$base" == ".git" ]] && continue
  [[ "$base" == "hardware-configuration.nix" ]] && continue
  cp -a "$f" "$MNT/etc/nixos/"
done
shopt -u dotglob nullglob

# ---- kurulum ----
log "nixos-install basliyor (root sifresi sorulacak)"
nixos-install --flake "path:$MNT/etc/nixos#${HOST_CFG}"

log "Kurulum tamamlandi. 'reboot' ile yeniden baslatabilirsin."
