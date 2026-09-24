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

  # Окружение Python со всеми библиотеками для парсинга и генерации epub
  bilingualPythonEnv = pkgs.python3.withPackages (ps: with ps; [
    requests
    beautifulsoup4
    tqdm
    ebooklib
    openai
    tiktoken
    rich
    tenacity
    lxml
    anthropic
    google-generativeai
  ]);
  # Исполняемый файл переводчика bilingual_book_maker. Апстрим недавно
  # переехал на новый CLI (--model_type/--openai_model/--deepl_key больше
  # не существуют, теперь --model/--api_format/--key) -- держим клон
  # свежим через git pull, чтобы не залипнуть на несовместимой версии.
  bilingualBookMaker = pkgs.writeShellScriptBin "bilingual_book_maker" ''
    set -euo pipefail
    APP_DIR="$HOME/.local/share/bilingual_book_maker"
    if [ ! -d "$APP_DIR" ]; then
      echo "Инициализация bilingual_book_maker в $APP_DIR..."
      mkdir -p "$HOME/.local/share"
      ${pkgs.git}/bin/git clone https://github.com/yihong0618/bilingual_book_maker.git "$APP_DIR"
    else
      ${pkgs.git}/bin/git -C "$APP_DIR" pull --ff-only --quiet || true
    fi
    exec ${bilingualPythonEnv}/bin/python "$APP_DIR/make_book.py" "$@"
  '';

  # Локальный конвертер PDF в чистый EPUB для читалки
  pdf2epub = pkgs.writeShellScriptBin "pdf2epub" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "Использование: pdf2epub <книга.pdf> [результат.epub]"
      exit 1
    fi
    IN="$1"
    if [ ! -f "$IN" ] && [ -f "$HOME/Загрузки/$IN" ]; then
      IN="$HOME/Загрузки/$IN"
    fi
    OUT="''${2:-''${IN%.*}.epub}"
    echo "Конвертация $IN в $OUT..."
    ${pkgs.calibre}/bin/ebook-convert "$IN" "$OUT" \
      --enable-heuristics \
      --smarten-punctuation
    echo "Готово: $OUT"
  '';
  # Автоматический конвейер: PDF/EPUB -> перевод -> билингвальный EPUB.
  # Использует актуальный CLI bilingual_book_maker: --model/--api_format/
  # --key вместо снятых --model_type/--openai_model/--deepl_key, плюс
  # --parallel-workers и --accumulated_num для реальной скорости (без них
  # каждый параграф шёл отдельным последовательным запросом -- отсюда и
  # 2 часа на 5 книг).
  translateBook = pkgs.writeShellScriptBin "translate-book" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      echo "Использование: translate-book <файл.pdf|файл.epub> [движок: ollama|openai|anthropic|deepl|deeplfree] [модель] [ключ]"
      echo "  ollama     -- локально, бесплатно, без ключа (нужен запущенный ollama + модель)"
      echo "  openai     -- translate-book книга.epub openai gpt-4o-mini sk-..."
      echo "  anthropic  -- translate-book книга.epub anthropic claude-haiku-4-5-20251001 sk-ant-..."
      echo "  deepl      -- translate-book книга.epub deepl - твой-ключ-от-deepl"
      echo "  deeplfree  -- бесплатный DeepL без ключа (менее надёжный лимитами)"
      exit 1
    fi
    IN="$1"
    ENGINE="''${2:-ollama}"
    MODEL="''${3:-}"
    KEY="''${4:-''${BBM_API_KEY:-}}"

    if [ ! -f "$IN" ] && [ -f "$HOME/Загрузки/$IN" ]; then
      IN="$HOME/Загрузки/$IN"
    fi

    BASE="''${IN%.*}"
    EPUB="$IN"

    if [[ "$IN" == *.pdf ]]; then
      EPUB="''${BASE}.epub"
      if [ ! -f "$EPUB" ]; then
        echo "Конвертация PDF в EPUB..."
        ${pkgs.calibre}/bin/ebook-convert "$IN" "$EPUB" --enable-heuristics --smarten-punctuation
      fi
    fi

    ARGS=()
    case "$ENGINE" in
      ollama)
        ARGS=(--api_format openai --api_base http://localhost:11434/v1 -m "''${MODEL:-qwen2.5:7b}")
        ;;
      openai)
        if [ -z "$KEY" ]; then
          echo "Ошибка: для openai нужен API-ключ (4-й аргумент или \$BBM_API_KEY)."
          exit 1
        fi
        ARGS=(--api_format openai -m "''${MODEL:-gpt-4o-mini}" --key "$KEY")
        ;;
      anthropic)
        if [ -z "$KEY" ]; then
          echo "Ошибка: для anthropic нужен API-ключ (4-й аргумент или \$BBM_API_KEY)."
          exit 1
        fi
        ARGS=(--api_format anthropic -m "''${MODEL:-claude-haiku-4-5-20251001}" --key "$KEY")
        ;;
      deepl)
        if [ -z "$KEY" ]; then
          echo "Ошибка: для DeepL нужен API-ключ (4-й аргумент или \$BBM_API_KEY)."
          exit 1
        fi
        ARGS=(--api_format deepl --key "$KEY")
        ;;
      deeplfree)
        ARGS=(--api_format deeplfree)
        ;;
      *)
        echo "Неизвестный движок: $ENGINE (доступно: ollama openai anthropic deepl deeplfree)"
        exit 1
        ;;
    esac

    echo "Генерация билингвального издания через $ENGINE..."
    ${bilingualBookMaker}/bin/bilingual_book_maker \
      --book_name "$EPUB" \
      --language ru \
      --parallel-workers 4 \
      --accumulated_num 2000 \
      --translation_style "font-size: 0.85em; color: #808080;" \
      "''${ARGS[@]}"
    echo "Готово! Проверь файлы рядом с $EPUB (обычно *_bilingual.epub)."
  '';
in
{
  imports = [ ./hardware-configuration.nix ];

  # ===== Ядро =====
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
    # Realtek BT 5.3 dongle (0bda:a729) fails its first descriptor read
    # ("device descriptor read/64, error -32"), forcing a ~80s enumeration
    # retry/reset that stalls boot ("A start job is running for
    # /dev/disk/by-uuid/...") and shutdown alike. NO_LPM quirk skips the
    # link-power-management negotiation that trips this up.
    "usbcore.quirks=0bda:a729:k"
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

  # Apple keyboard hwdb
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

  # ===== Display Manager: SDDM =====
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

  # ===== Файловый менеджер и накопители (Nemo / GVfs / UDisks2) =====
  services.gvfs.enable = true;        # Корзина, Kobo (USB/MTP), внешние диски и сетевые папки
  services.udisks2.enable = true;     # Монтирование накопителей без sudo
  security.polkit.enable = true;      # Права доступа к накопителям
  services.tumbler.enable = true;     # D-Bus генератор эскизов (картинки, видео, PDF)
  programs.dconf.enable = true;       # База настроек для Nemo, анимаций GTK и закреплений

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
    NIXOS_OZONE_WL = "1";
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

  # ===== Ollama (локальный движок для translate-book ollama) =====
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda; # RTX 2070
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

  # ===== CPU / Системные демоны =====
  powerManagement.cpuFreqGovernor = "schedutil";
  services.thermald.enable = true;

  # ===== OOM =====
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
  };

  # ===== SSD & Виртуализация =====
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

  # ===== Порталы =====
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
    # --- Файловый менеджер (Nemo) и компоненты ---
    nemo-with-extensions
    file-roller           # Распаковка/сжатие через ПКМ ("Извлечь сюда", "Создать архив")
    webp-pixbuf-loader    # Эскизы изображений WebP
    libgsf                # Эскизы офисных документов ODF
    poppler               # Эскизы и работа с PDF
    ffmpegthumbnailer     # Эскизы видеофайлов

    # --- CLI утилиты ---
    git wget curl htop btop tree file unzip zip p7zip unrar
    ripgrep fd fzf fastfetch tmux rsync jq ncdu bat eza tldr lsof psmisc
    pciutils usbutils lm_sensors nmap mtr whois dnsutils gnupg sshfs
    zoxide direnv duf xclip wl-clipboard mpvpaper
    cava unar xwayland-satellite satty hyprpolkitagent linux-wallpaperengine

    # --- Разработка ---
    claude-code python3
    elan lean4

    # --- GUI программы ---
    nixosGreeterTheme hmcl
    hicolor-icon-theme adwaita-icon-theme
    vlc virt-manager gimp inkscape
    (vscode.override { commandLineArgs = "--enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland"; })
    obs-studio qbittorrent gparted
    dconf-editor blueman jdk17 

    # --- AppImage & Wine ---
    appimage-run wine steam-run libepoxy

    # --- Медиа ---
    telegram-desktop playerctl mpv ffmpeg yt-dlp imagemagick

    # --- Чтение, верстка и перевод ---
    jmtpfs zotero calibre onlyoffice-desktopeditors zathura
    pdf2epub              # Локальная конвертация PDF -> EPUB с очисткой верстки
    translateBook         # Автоматический пайплайн двуязычного перевода
    bilingualBookMaker    # CLI утилита параллельного перевода

    # --- Текст ---
    pandoc bibata-cursors rnote

    # --- Niri / Wayland utils ---
    foot starship
    grim slurp fftw

    # --- Интеграция ---
    flatpak desktop-file-utils xdg-utils 
  ];

  system.stateVersion = "26.05";
}
