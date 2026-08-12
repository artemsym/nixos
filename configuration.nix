{ config, pkgs, ... }:
let
  nixosGreeterTheme = (pkgs.where-is-my-sddm-theme.override {
    themeConfig.General = {
      background = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      passwordInputWidth = "0.225";
      passwordFontSize = "36";
    };
  }).overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      cp ${./sddm-theme/Main.qml} where_is_my_sddm_theme/Main.qml
    '';
  });

  # Sets a live gain (dB) on one band of the caelestia-eq PipeWire sink
  # (see services.pipewire.extraConfig below). Looks the sink's node id up
  # by name each call since it isn't stable across restarts.
  caelestiaEqSet = pkgs.writeShellScriptBin "caelestia-eq-set" ''
    set -euo pipefail
    band=$1
    gain=$2
    id=$(${pkgs.pipewire}/bin/pw-dump | ${pkgs.jq}/bin/jq -r '
      .[] | select(.info.props."node.name" == "effect_input.caelestia_eq") | .id
    ' | head -n1)
    if [ -z "$id" ]; then
      exit 0
    fi
    ${pkgs.pipewire}/bin/pw-cli s "$id" Props "{ params = [ \"$band:Gain\" $gain ] }" >/dev/null
  '';
in
{
  imports = [ ./hardware-configuration.nix ];

  # ===== Ядро =====
  # Zen: low-latency планировщик заточенный под десктоп/игры (в духе того,
  # что использует CachyOS), уже в основном nixpkgs — без сторонних кэшей.
  boot.kernelPackages = pkgs.linuxPackages_zen;

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
  documentation.nixos.enable = false;
  documentation.doc.enable = false;
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

  # Apple keyboard (vendor 05ac, product 024f): F1-F12 send their fn-media
  # actions (brightness/dashboard/kbd-illum/media/volume) by default. Force
  # the F-row to always send plain F1-F12 instead.
  services.udev.extraHwdb = ''
    evdev:input:b*v05ACp024F*
     KEYBOARD_KEY_7003a=f1
     KEYBOARD_KEY_7003b=f2
     KEYBOARD_KEY_7003c=f3
     KEYBOARD_KEY_7003d=f4
     KEYBOARD_KEY_7003e=f5
     KEYBOARD_KEY_7003f=f6
     KEYBOARD_KEY_70040=f7
     KEYBOARD_KEY_70041=f8
     KEYBOARD_KEY_70042=f9
     KEYBOARD_KEY_70043=f10
     KEYBOARD_KEY_70044=f11
     KEYBOARD_KEY_70045=f12
  '';

  # ===== Display Manager: SDDM (custom NixOS greeter theme) =====

  services.displayManager.sddm = {
    enable = true;
    theme = "where_is_my_sddm_theme";
    wayland.enable = true;
    wayland.compositor = "kwin";
    extraPackages = [ pkgs.qt6.qt5compat pkgs.qt6.qtsvg ];
  };

  systemd.services.display-manager.environment.QML_DISABLE_DISK_CACHE = "1";
  systemd.services.display-manager.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/rm -rf /var/lib/sddm/.cache";

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
    NIXOS_OZONE_WL = "1"; # forces Electron apps (VS Code) onto native Wayland instead of XWayland, fixes window-rule opacity/blur breaking on focus repaint
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

    # 3-band (bass/mid/treble) EQ sink, controlled live from the caelestia
    # media widget. Structure copied from PipeWire's own upstream example
    # (src/daemon/filter-chain/sink-eq6.conf), trimmed to 3 bands. Creates
    # a new "Caelestia EQ Sink" output device -- select it once as your
    # default output (e.g. in pavucontrol) for it to actually apply.
    extraConfig.pipewire."92-caelestia-eq" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Caelestia EQ Sink";
            "media.name" = "Caelestia EQ Sink";
            "filter.graph" = {
              nodes = [
                {
                  type = "builtin";
                  name = "eq_bass";
                  label = "bq_lowshelf";
                  control = {
                    Freq = 100.0;
                    Q = 1.0;
                    Gain = 0.0;
                  };
                }
                {
                  type = "builtin";
                  name = "eq_mid";
                  label = "bq_peaking";
                  control = {
                    Freq = 1000.0;
                    Q = 1.0;
                    Gain = 0.0;
                  };
                }
                {
                  type = "builtin";
                  name = "eq_treble";
                  label = "bq_highshelf";
                  control = {
                    Freq = 8000.0;
                    Q = 1.0;
                    Gain = 0.0;
                  };
                }
              ];
              links = [
                { output = "eq_bass:Out"; input = "eq_mid:In"; }
                { output = "eq_mid:Out"; input = "eq_treble:In"; }
              ];
            };
            "audio.channels" = 2;
            "audio.position" = [ "FL" "FR" ];
            "capture.props" = {
              "node.name" = "effect_input.caelestia_eq";
              "media.class" = "Audio/Sink";
            };
            "playback.props" = {
              "node.name" = "effect_output.caelestia_eq";
              "node.passive" = true;
            };
          };
        }
      ];
    };
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
    caelestiaEqSet
    hicolor-icon-theme adwaita-icon-theme
    vlc virt-manager gimp inkscape
    (vscode.override { commandLineArgs = "--enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland"; })
    obs-studio qbittorrent gparted
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
    foot starship
    grim slurp fftw

    # --- Разное ---
    flatpak desktop-file-utils xdg-utils 
  ];

  system.stateVersion = "26.05";
}
