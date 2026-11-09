{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Flakes ve yeni Nix komutlarını etkinleştir
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Önyükleyici (Bootloader) Ayarları
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- YENİ EKLENTİ: NVIDIA Wayland Kararlılığı İçin Kernel Parametresi ---
  boot.kernelParams = [ "nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" ];

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
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

# hicabi kullanıcısı için otomatik oturum açma
services.displayManager.autoLogin = {
  enable = true;
  user = "hicabi";
};

  # KDE PIM kapalı
  programs.kde-pim.enable = false;

  # Plasma 6 varsayılanlarından istenmeyen ek uygulamaları çıkar
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    akonadi
    kmail
    kmail-account-wizard
    kdepim-runtime
    kontact
    korganizer
    kaddressbook
    elisa
    khelpcenter
    krdp
  ];

  # Flatpak ve AppImage Desteği
  services.flatpak.enable = true;
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Kullanıcı Tanımlaması: hicabi
  users.users.hicabi = {
    isNormalUser = true;
    description = "Hicabi";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPassword = "$6$uP4vjE0Zqg7xX3N5$m4HExIuD9ZgO8Z3aT9N9/E7Lclp1b9wK.Z/9T0b3mRE5d5lXo8xXNuxfTjY7MvMWhG4y0Mre.V86oBms5nCg1/";
  };

  # Unfree yazılımlara izin ver
  nixpkgs.config.allowUnfree = true;

  # NVIDIA RTX 4060 Ayarları
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Wayland ve Çevre Değişkenleri (DÜZELTİLDİ)
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Düzeltildi: URL yerine WL
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # Sistem Paketleri
  environment.systemPackages = with pkgs; [
    firefox
    kdePackages.kate
    kdePackages.kcalc
    cudaPackages.cudatoolkit
    git
    curl
    wget
    unzip
    pciutils
    gnumake
    pkgs.lact

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

  system.stateVersion = "24.11";


  # Bluetooth'u etkinleştir
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true; # Bilgisayar açıldığında Bluetooth'u çalıştır

  # KDE Plasma'nın Bluetooth widget'ı ve ayar yöneticisi için gerekli paketler
  services.blueman.enable = true; # İsteğe bağlıdır ancak sorun giderme için faydalıdır

  # Servis ayarını ana süslü parantezlerin içine, bağımsız bir satır olarak ekleyin:
services.lact.enable = true;
}

