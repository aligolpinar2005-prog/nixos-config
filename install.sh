#!/usr/bin/env bash
# NixOS otomatik kurulum (UEFI + M.2 NVMe)
# Kullanim:  sudo DISK=/dev/nvme0n1 bash install.sh
# Not: Calistirdigin disk TAMAMEN SILINIR.
set -euo pipefail
#!/usr/bin/env bash
# NixOS Otomatik Kurulum Scripti (UEFI + M.2 NVMe)
# Kullanım: sudo DISK=/dev/nvme0n1 HOST_CFG=nixos bash install.sh

set -euo pipefail

DISK="${DISK:-/dev/nvme0n1}"
# flake.nix içerisindeki nixosConfigurations başlığını buraya yazın:
HOST_CFG="${HOST_CFG:-nixos}" 
MNT=/mnt
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

# ---- Ön Kontroller ----
[[ $EUID -eq 0 ]] || die "Root olarak çalıştırın (sudo ...)."
[[ -d /sys/firmware/efi ]] || die "Sistem UEFI modunda değil. BIOS'tan UEFI'yi açın."
[[ -b "$DISK" ]] || die "Disk bulunamadı: $DISK"

for c in sgdisk mkfs.fat mkfs.ext4 git nixos-generate-config nixos-install; do
  command -v "$c" >/dev/null 2>&1 || die "Gerekli komut eksik: $c"
done

for f in flake.nix configuration.nix; do
  [[ -f "$REPO_DIR/$f" ]] || die "$REPO_DIR/$f bulunamadı."
done

# ---- İnternet Bağlantısı Kontrolü ----
if ! ping -c1 -W3 nixos.org >/dev/null 2>&1; then
  log "UYARI: İnternet bağlantısı tespit edilemedi. nixos-install paketleri indiremeyebilir."
fi

# ---- Disk Doğrulama ----
log "Hedef Disk Bilgisi: $DISK"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK" || true
echo
read -rp "!! $DISK ÜZERİNDEKİ TÜM VERİLER SİLİNECEK. Devam etmek için 'SIL' yazın: " ans
[[ "$ans" == "SIL" ]] || die "İşlem iptal edildi."

# ---- Bölüm Adı Eki (NVMe / MMC için 'p' ekler) ----
if [[ "$DISK" =~ [0-9]$ ]]; then SUF=p; else SUF=""; fi
ESP="${DISK}${SUF}1"
ROOT="${DISK}${SUF}2"

# ---- Mevcut Mount/Swap Kapatma ----
log "Eski mount ve swap alanları kapatılıyor..."
umount -R "$MNT" 2>/dev/null || true
swapoff -a 2>/dev/null || true

# ---- Bölümleme ----
log "Disk temizleniyor ve bölümleniyor (sgdisk)..."
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
sleep 2

# ---- Biçimlendirme (Format) ----
log "Bölümler biçimlendiriliyor..."
mkfs.fat -F32 -n EFI "$ESP"
mkfs.ext4 -F -L NIXOS "$ROOT"

# ---- Bağlama (Mount) ----
log "Bölümler $MNT dizinine bağlanıyor..."
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot"
mount "$ESP" "$MNT/boot"

# ---- Donanım Yapılandırması Üretme ----
log "Donanım yapılandırması üretiliyor (nixos-generate-config)..."
nixos-generate-config --root "$MNT"

# ---- Repo Dosyalarını Kopyalama ----
log "Yapılandırma dosyaları $MNT/etc/nixos dizinine kopyalanıyor..."
mkdir -p "$MNT/etc/nixos"
shopt -s dotglob nullglob
for f in "$REPO_DIR"/*; do
  base="$(basename "$f")"
  [[ "$base" == ".git" ]] && continue
  # Otomatik üretilen donanım yapılandırmasını koruyoruz:
  [[ "$base" == "hardware-configuration.nix" ]] && continue 
  cp -a "$f" "$MNT/etc/nixos/"
done
shopt -u dotglob nullglob

# ---- Kurulum ----
log "nixos-install başlatılıyor (${HOST_CFG} profili ile)..."
nixos-install --flake "path:$MNT/etc/nixos#${HOST_CFG}"

log "Kurulum başarıyla tamamlandı! 'reboot' komutu ile sistemi yeniden başlatabilirsiniz."


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
