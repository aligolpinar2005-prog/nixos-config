#!/usr/bin/env bash
# NixOS Otomatik Kurulum (UEFI + M.2 NVMe - Kesin Hizalanmış)
set -euo pipefail

DISK="${DISK:-/dev/nvme0n1}"
HOST_CFG="${HOST_CFG:-nixos}"
MNT=/mnt
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Root yetkisiyle çalıştırın (sudo bash install.sh)."
[[ -d /sys/firmware/efi ]] || die "Sistem UEFI modunda değil."
[[ -b "$DISK" ]] || die "Disk bulunamadı: $DISK"

# Disk doğrulama
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK" || true
echo
read -rp "!! $DISK TAMAMEN SİLİNECEK. Devam etmek için 'SIL' yazın: " ans
[[ "$ans" == "SIL" ]] || die "İptal edildi."

if [[ "$DISK" =~ [0-9]$ ]]; then SUF=p; else SUF=""; fi
ESP="${DISK}${SUF}1"
ROOT="${DISK}${SUF}2"

log "Mevcut mount ve swap noktaları temizleniyor"
umount -R "$MNT" 2>/dev/null || true
swapoff -a 2>/dev/null || true

log "Disk sıfırlanıyor ve 1MiB hizada bölümleniyor"
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sync

# 1MiB hizalamalı bölümler (-a 2048)
sgdisk -a 2048 \
  -n 1:0:+512M -t 1:ef00 -c 1:ESP \
  -n 2:0:0     -t 2:8300 -c 2:nixos \
  "$DISK"

sync
partprobe "$DISK" || blockdev --rereadpt "$DISK" || true
udevadm settle
sleep 3

# Bölümlerin kernel tarafından görünür olmasını garantileme
for i in {1..5}; do
  [[ -b "$ROOT" && -b "$ESP" ]] && break
  sleep 1
done

log "Dosya sistemleri güvenli şekilde biçimlendiriliyor"
mkfs.fat -F32 -n "boot" "$ESP"
mkfs.ext4 -F -L "nixos" "$ROOT"
sync
udevadm settle

log "Diskler mount ediliyor"
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot"
mount "$ESP" "$MNT/boot"

log "NixOS yapılandırması üretiliyor ve dosyalar kopyalanıyor"
nixos-generate-config --root "$MNT"

mkdir -p "$MNT/etc/nixos"
shopt -s dotglob nullglob
for f in "$REPO_DIR"/*; do
  base="$(basename "$f")"
  [[ "$base" == ".git" ]] && continue
  [[ "$base" == "hardware-configuration.nix" ]] && continue
  cp -a "$f" "$MNT/etc/nixos/"
done
shopt -u dotglob nullglob

if [ ! -d "$MNT/etc/nixos/.git" ]; then
  git -C "$MNT/etc/nixos" init --quiet
  git -C "$MNT/etc/nixos" config user.name "NixOS Installer"
  git -C "$MNT/etc/nixos" config user.email "installer@nixos"
  git -C "$MNT/etc/nixos" add .
fi

log "nixos-install başlatılıyor..."
nixos-install --flake "$MNT/etc/nixos#${HOST_CFG}"

log "Kurulum tamamlandı! reboot komutuyla yeniden başlatabilirsiniz."
