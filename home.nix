{ config, pkgs, ... }:

{
  home.username = "hicabi";
  home.homeDirectory = "/home/hicabi";

  # Kullanıcı düzeyinde yüklenecek paketler
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.konsole
    # Buraya kullanıcıya özel ek flatpak/appimage araçları veya CLI araçları ekleyebilirsiniz
  ];

  # Klasik dotfile/dosya yönetimi kuralları gerekirse buraya yazılır
  home.file = {};

  home.sessionVariables = {
    EDITOR = "kate";
  };

  # Home Manager'ın kendisini yönetmesini sağla
  programs.home-manager.enable = true;

  home.stateVersion = "24.11"; # Değiştirmeyin
}
