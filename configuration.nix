{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix # Kurulum sırasında otomatik oluşan dosyayı değiştirmeyin
  ];

  # Flakes ve yeni Nix komutlarını etkinleştir
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Önyükleyici (Bootloader) Ayarları
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Zaman Dilimi ve Dil Ayarları (Türkçe)
  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "tr_TR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "tr_TR.UTF-8";
    LC_IDENTIFICATION = "tr_TR.UTF-8";
    LC_MEASUREMENT = "tr_TR.UTF-8";
    LC_MONETARY = "tr_TR.UTF-8";
    LC_NAME = "tr_TR.UTF-8";
    LC_NUMERIC = "tr_TR.UTF-8";
    LC_PAPER = "tr_TR.UTF-8";
    LC_TELEPHONE = "tr_TR.UTF-8";
    LC_TIME = "tr_TR.UTF-8";
  };
  console.keyMap = "trq";

  # Grafik Sunucusu ve Masaüstü Ortamı (KDE Plasma 6)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true; # Wayland varsayılan ve optimize
  };
  services.desktopManager.plasma6.enable = true;

  # KMail, Akonadi ve gereksiz KDE araçlarını sistemden tamamen çıkar
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    akonadi
    kmail
    kmail-account-wizard
    kdepim-runtime
    kontact
    korganizer
    kaddressbook
  ];

  # Flatpak Desteği
  services.flatpak.enable = true;

  # AppImage Desteği (AppImage'ların doğrudan çalışabilmesi için binfmt kaydı)
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Kullanıcı Tanımlaması: hicabi
  # Şifre: 2363/*- (Güvenlik için SHA-512 hash'i yerleştirilmiştir)
  users.users.hicabi = {
    isNormalUser = true;
    description = "Hicabi";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPassword = "$6$uP4vjE0Zqg7xX3N5$m4HExIuD9ZgO8Z3aT9N9/E7Lclp1b9wK.Z/9T0b3mRE5d5lXo8xXNuxfTjY7MvMWhG4y0Mre.V86oBms5nCg1/";
  };

  # Unfree (Özgür olmayan) yazılımlara izin ver (NVIDIA ve CUDA için zorunlu)
  nixpkgs.config.allowUnfree = true;

  # NVIDIA RTX 4060 Açık Kaynaklı (Open) Sürücü ve CUDA Ayarları
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true; # Açık kaynaklı (open-source) çekirdek modüllerini kullan
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Wayland ve Çevre Değişkenleri Optimizasyonları
  environment.sessionVariables = {
    NIXOS_OZONE_GFX_URL = "1";
    MOZ_ENABLE_WAYLAND = "1"; # Firefox Wayland yerel modu
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Sistem Paketleri (Gerekli temel araçlar, Firefox ve CUDA)
  environment.systemPackages = with pkgs; [
    # İstenen uygulamalar
    firefox
    kdePackages.kate
    kdePackages.kcalc # Ekstra kullanışlı KDE araçları

    # CUDA ve Geliştirme Araçları
    cudaPackages.cudatoolkit

    # Gerekli sistem araçları
    git
    curl
    wget
    unzip
    pciutils
    gnumake
  ];

  # Ses Ayarları (Pipewire)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Ağ Ayarları
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  system.stateVersion = "24.11"; # Değiştirmeyin
}
