#!/usr/bin/env bash
# NixOS otomatik kurulum (UEFI + M.2 NVMe)
# Kullanım: sudo DISK=/dev/nvme0n1 bash install.sh
# Not: Çalıştırdığın disk TAMAMEN SİLİNİR.
set -euo pipefail

DISK="${DISK:-/dev/nvme0n1}"
HOST_CFG="${HOST_CFG:-nixos}"
MNT=/mnt
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

# ---- Ön kontroller ----
[[ $EUID -eq 0 ]] || die "Root olarak çalıştırın (sudo bash install.sh)."
[[ -d /sys/firmware/efi ]] || die "Sistem UEFI modunda değil. BIOS'tan UEFI'yi açın."
[[ -b "$DISK" ]] || die "Disk bulunamadı: $DISK"

for c in sgdisk mkfs.fat mkfs.ext4 git nixos-generate-config nixos-install; do
  command -v "$c" >/dev/null 2>&1 || die "Gerekli komut eksik: $c"
done

for f in flake.nix configuration.nix home.nix; do
  [[ -f "$REPO_DIR/$f" ]] || die "$REPO_DIR/$f dosyası bulunamadı."
done

# ---- İnternet kontrolü ----
if ! ping -c1 -W3 nixos.org >/dev/null 2>&1; then
  log "UYARI: İnternet bağlantısı algılanamadı. nixos-install paketleri indiremeyebilir."
fi

# ---- Disk doğrulama ----
log "Disk bilgisi: $DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK" || true
echo
read -rp "!! $DISK TAMAMEN SİLİNECEK. Devam etmek için 'SIL' yazın: " ans
[[ "$ans" == "SIL" ]] || die "İptal edildi."

# ---- Bölüm adı eki (nvme/mmc -> p, sdX -> boş) ----
if [[ "$DISK" =~ [0-9]$ ]]; then SUF=p; else SUF=""; fi
ESP="${DISK}${SUF}1"
ROOT="${DISK}${SUF}2"

# ---- Mevcut mount/swap kapatma ----
log "Olası mount/swap noktaları kapatılıyor"
umount -R "$MNT" 2>/dev/null || true
swapoff -a 2>/dev/null || true

# ---- Bölümleme ----
log "Disk sıfırlanıyor ve bölümleniyor (sgdisk)"
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

# ---- Formatlama ----
log "Dosya sistemleri biçimlendiriliyor"
mkfs.fat -F32 -n "boot" "$ESP"
mkfs.ext4 -F -L "nixos" "$ROOT"

# ---- Mount İşlemleri ----
log "Diskler mount ediliyor"
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot"
mount "$ESP" "$MNT/boot"

# ---- Donanım Yapılandırması ----
log "Donanım yapılandırması üretiliyor (nixos-generate-config)"
nixos-generate-config --root "$MNT"

# ---- Repo Dosyalarını Kopyalama ----
log "Yapılandırma dosyaları $MNT/etc/nixos adresine kopyalanıyor"
mkdir -p "$MNT/etc/nixos"
shopt -s dotglob nullglob
for f in "$REPO_DIR"/*; do
  base="$(basename "$f")"
  [[ "$base" == ".git" ]] && continue
  [[ "$base" == "hardware-configuration.nix" ]] && continue
  cp -a "$f" "$MNT/etc/nixos/"
done
shopt -u dotglob nullglob

# Flake'in git takibindeki dosyaları görebilmesi için geçici git init/add
if [ ! -d "$MNT/etc/nixos/.git" ]; then
  git -C "$MNT/etc/nixos" init --quiet
  git -C "$MNT/etc/nixos" config user.name "NixOS Installer"
  git -C "$MNT/etc/nixos" config user.email "installer@nixos"
  git -C "$MNT/etc/nixos" add .
fi

# ---- Kurulum ----
log "nixos-install başlatılıyor..."
nixos-install --flake "$MNT/etc/nixos#${HOST_CFG}"

log "Kurulum tamamlandı. 'reboot' ile sistemi yeniden başlatabilirsiniz."
