{ config, pkgs, ... }:
let
  nixosGreeterTheme = (pkgs.where-is-my-sddm-theme.override {
    themeConfig.General = {
      background = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      passwordInputWidth = "0.15";
      passwordFontSize = "24";
    };
  }).overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cp ${./sddm-theme/Main.qml} where_is_my_sddm_theme/Main.qml
    '';
  });
in
{
  imports = [ ./hardware-configuration.nix ];
  
  # ===== Загрузчик =====
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.editor = false;

  # ===== Ядро / NVIDIA =====
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  boot.blacklistedKernelModules = [ "nouveau" ];
  # ===== Сеть =====
  networking.hostName = "gothness";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ ];
    trustedInterfaces = [ "lo" ];
    interfaces."eno1".allowedUDPPorts = [ 53 ];
  };
  services.v2raya.enable = true;
  services.v2raya.cliPackage = pkgs.xray;
  systemd.services.v2raya = {
    path = with pkgs; [ iptables nftables iproute2 bash ];
    serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];
    };
  };

  # ===== Nix =====
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # ===== AppImage =====
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # ===== Чужие бинарники =====
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib at-spi2-atk at-spi2-core atk cairo cups curl dbus expat ffmpeg
    fontconfig freetype gdk-pixbuf glib gtk3 libGL libdrm libepoxy libnotify
    libpulseaudio libsecret libxkbcommon mesa nss nspr openssl pango stdenv.cc.cc.lib
    systemd udev vulkan-loader wayland zlib krb5
  ];

  # ===== Локализация =====
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # ===== zram =====
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ===== Клавиатура =====
  services.xserver.enable = false;
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:alt_shift_toggle";
  };
  console.useXkbConfig = true;

  # ===== Display Manager: SDDM (custom NixOS greeter theme) =====

  services.displayManager.sddm = {
    enable = true;
    theme = "where_is_my_sddm_theme";
    wayland.enable = true;
    wayland.compositor = "kwin";
    extraPackages = [ pkgs.qt6.qt5compat pkgs.qt6.qtsvg ];
  };

  environment.etc."issue".text = "";

  # ===== Niri =====

  programs.niri.enable = true;

  environment.etc."wayland-sessions".source =
    "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
  # ===== NVIDIA =====
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # ===== Звук =====
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # ===== Bluetooth =====
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
    };
  };
  services.blueman.enable = true;

  # ===== Печать =====
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ===== Steam =====
  programs.steam.enable = true;
  programs.gamemode.enable = true;
  hardware.steam-hardware.enable = true;

  # ===== CPU =====
  powerManagement.cpuFreqGovernor = "schedutil";
  services.thermald.enable = true;

  # ===== OOM =====
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
  };

  # ===== SSD =====
  services.fstrim.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
  virtualisation.libvirtd.enable = true;
  # ===== Пользователь =====
  users.users.gothness = {
    isNormalUser = true;
    description = "gothness";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "libvirtd"
      "audio"
    ];
  };

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  # ===== Flatpak =====
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # ===== Шрифты =====
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    dejavu_fonts
    font-awesome
    comic-mono
    cascadia-code
    victor-mono
    nerd-fonts.jetbrains-mono
    corefonts
  ];

  # ===== Пакеты =====
  environment.systemPackages = with pkgs; [
    # --- CLI ---
    git wget curl htop btop tree file unzip zip p7zip unrar
    ripgrep fd fzf fastfetch tmux rsync jq ncdu bat eza tldr lsof psmisc
    pciutils usbutils lm_sensors nmap mtr whois dnsutils gnupg sshfs
    zoxide direnv duf xclip wl-clipboard mpvpaper yazi ffmpegthumbnailer
    cava unar poppler xwayland-satellite satty hyprpolkitagent linux-wallpaperengine

    # --- Разработка ---
    claude-code python3
    elan lean4

    # --- GUI ---
    nixosGreeterTheme
    hicolor-icon-theme adwaita-icon-theme
    vlc virt-manager gimp inkscape
    vscode obs-studio qbittorrent gparted
    dconf-editor blueman osu-lazer-bin

    # --- AppImage ---
    appimage-run steam-run libepoxy

    # --- Медиа ---
    telegram-desktop playerctl mpv ffmpeg yt-dlp imagemagick

    # --- Чтение ---
    zotero calibre onlyoffice-desktopeditors zathura

    # --- Текст ---
    pandoc bibata-cursors

    # --- Niri / Wayland utils ---
    matugen material-symbols waybar foot starship
    grim slurp wofi fftw

    # --- Разное ---
    flatpak desktop-file-utils xdg-utils 
  ];

  system.stateVersion = "26.05";
}
