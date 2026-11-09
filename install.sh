cat << 'EOF' > install.sh
#!/usr/bin/env bash
# NixOS Otomatik Kurulum (UEFI + M.2 NVMe - Tam Hizalanmış GPT)
# Kullanım: sudo DISK=/dev/nvme0n1 bash install.sh
# NOT: Seçilen disk üzerindeki tüm veriler SILINECEKTIR.
set -euo pipefail

DISK="${DISK:-/dev/nvme0n1}"
HOST_CFG="${HOST_CFG:-nixos}"
MNT=/mnt
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

# ---- Ön Kontroller ----
[[ $EUID -eq 0 ]] || die "Root yetkisiyle çalıştırın (sudo bash install.sh)."
[[ -d /sys/firmware/efi ]] || die "Sistem UEFI modunda değil. BIOS'tan UEFI'yi aktif edin."
[[ -b "$DISK" ]] || die "Disk bulunamadı: $DISK"

for c in sgdisk mkfs.fat mkfs.ext4 git nixos-generate-config nixos-install; do
  command -v "$c" >/dev/null 2>&1 || die "Gerekli komut eksik: $c"
done

for f in flake.nix configuration.nix home.nix; do
  [[ -f "$REPO_DIR/$f" ]] || die "$REPO_DIR/$f dosyası bulunamadı."
done

# ---- İnternet Kontrolü ----
if ! ping -c1 -W3 nixos.org >/dev/null 2>&1; then
  log "UYARI: İnternet bağlantısı yok. nixos-install paketleri indiremeyebilir."
fi

# ---- Disk Doğrulama ----
log "Disk bilgisi: $DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK" || true
echo
read -rp "!! $DISK TAMAMEN SİLİNECEK. Devam etmek için 'SIL' yazın: " ans
[[ "$ans" == "SIL" ]] || die "İptal edildi."

# ---- Bölüm Adı Eki (nvme/mmc -> p, sdX -> boş) ----
if [[ "$DISK" =~ [0-9]$ ]]; then SUF=p; else SUF=""; fi
ESP="${DISK}${SUF}1"
ROOT="${DISK}${SUF}2"

# ---- Kilitleri Kapatma ve Temizlik ----
log "Mevcut mount ve swap noktaları kapatılıyor"
umount -R "$MNT" 2>/dev/null || true
swapoff -a 2>/dev/null || true

log "Disk tabloları ve imzaları temizleniyor"
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
sync

# ---- Tam Hizalı Bölümleme (1 MiB Alignment) ----
log "Disk optimal sektör hizalaması (1MiB Alignment) ile bölümleniyor"
# -a 2048: Bölümlerin 2048 sektör (1 MiB) katlarına tam oturmasını zorunlu kılar.
# -n 1:0:+512M: 1. bölüm (ESP) ilk hizalı sektörden başlar ve tam 512MB olur.
# -n 2:0:0: 2. bölüm (Root) ESP'nin bittiği ilk hizalı sektörden başlar ve diskin sonuna kadar uzanır.
sgdisk -a 2048 \
  -n 1:0:+512M -t 1:ef00 -c 1:ESP \
  -n 2:0:0     -t 2:8300 -c 2:nixos \
  "$DISK"

# Kernel'e yeni tabloyu bildirme
sync
if command -v partprobe >/dev/null 2>&1; then
  partprobe "$DISK"
else
  blockdev --rereadpt "$DISK" || true
fi
udevadm settle

# Hizalama Doğrulaması
log "Bölüm tablosu ve hizalama kontrol ediliyor:"
sgdisk -v "$DISK"
sgdisk -p "$DISK"

# ---- Formatlama ----
log "Dosya sistemleri biçimlendiriliyor (FAT32 & EXT4)"
mkfs.fat -F32 -n "boot" "$ESP"
mkfs.ext4 -F -L "nixos" "$ROOT"

# ---- Mount İşlemleri ----
log "Diskler mount ediliyor"
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot"
mount "$ESP" "$MNT/boot"

# ---- NixOS Yapılandırması ve Kurulum ----
log "Donanım yapılandırması üretiliyor (nixos-generate-config)"
nixos-generate-config --root "$MNT"

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

# Flake git takibi kontrolü
if [ ! -d "$MNT/etc/nixos/.git" ]; then
  git -C "$MNT/etc/nixos" init --quiet
  git -C "$MNT/etc/nixos" config user.name "NixOS Installer"
  git -C "$MNT/etc/nixos" config user.email "installer@nixos"
  git -C "$MNT/etc/nixos" add .
fi

log "nixos-install başlatılıyor..."
nixos-install --flake "$MNT/etc/nixos#${HOST_CFG}"

log "Kurulum başarıyla tamamlandı. 'reboot' ile sistemi yeniden başlatabilirsiniz."
EOF
