{ config, pkgs, inputs, ... }:
let
  caelestiaShellPkg = inputs.niri-caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-shell.override {
    # upstream's nix/app2unit.nix pins app2unit 1.0.3 but inherits nixpkgs'
    # postFixup for the current (1.4.4) version, whose substituteInPlace
    # pattern doesn't exist in 1.0.3's script -> build fails. Use plain
    # nixpkgs app2unit instead of the broken pinned override.
    app2unit = pkgs.app2unit;
    # Needed for colour theming (caelestia-cli) and for the idle-lock
    # service below to be able to call the shell's lock IPC.
    withCli = true;
  };
in
{
  imports = [ inputs.niri-caelestia-shell.homeManagerModules.default ];

  home.username = "gothness";
  home.homeDirectory = "/home/gothness";
  home.stateVersion = "26.05";

  # ===== Niri =====
  xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;

  # ===== Caelestia Shell (niri port) =====
  # Replaces waybar: https://github.com/jutraim/niri-caelestia-shell
  # Upstream's own module option is `programs.caelestia` (its README's
  # `programs.niri-caelestia-shell` example is stale/aspirational and
  # doesn't match the actual nix/hm-module.nix in the repo).
  programs.caelestia = {
    enable = true;
    # Plain build, no caelestia-cli: upstream README states the CLI is
    # not required for the Niri port.
    package = caelestiaShellPkg;

    # Without this, `caelestia` (the CLI) is only reachable from inside the
    # wrapped shell's own subprocess PATH (needed for its QML execDetached
    # calls) — it's NOT on your interactive $PATH, so running `caelestia`
    # by hand does nothing.
    cli.enable = true;

    settings = {
      appearance = {
        anim.durations.scale = 1;
        font = {
          family = {
            material = "Material Symbols Rounded";
            mono = "CaskaydiaCove NF";
            sans = "Rubik";
          };
          size.scale = 1;
        };
        padding.scale = 1;
        rounding.scale = 1;
        spacing.scale = 1;
        transparency = {
          enabled = false;
          base = 0.85;
          layers = 0.4;
        };
      };

      general.apps = {
        terminal = [ "foot" ];
        audio = [ "pavucontrol" ];
      };

      background = {
        desktopClock.enabled = false;
        enabled = false; # linux-wallpaperengine (systemd service below) draws the actual wallpaper; caelestia's own background layer was covering it
        visualiser = {
          enabled = true;
          autoHide = true;
          rounding = 1;
          spacing = 1;
        };
      };

      bar = {
        clock.showIcon = false;
        dragThreshold = 20;
        entries = [
          { id = "logo"; enabled = true; }
          { id = "workspaces"; enabled = true; }
          { id = "spacer"; enabled = true; }
          { id = "activeWindow"; enabled = true; }
          { id = "spacer"; enabled = true; }
          { id = "tray"; enabled = true; }
          { id = "clock"; enabled = true; }
          { id = "statusIcons"; enabled = true; }
          { id = "power"; enabled = true; }
          { id = "idleInhibitor"; enabled = false; }
        ];
        persistent = false;
        showOnHover = true;
        status = {
          showAudio = false;
          showBattery = true;
          showBluetooth = true;
          showMicrophone = false;
          showKbLayout = false;
          showNetwork = true;
        };
        tray = {
          background = true;
          recolour = true;
        };
        workspaces = {
          activeIndicator = true;
          activeLabel = "󰮯";
          activeTrail = false;
          groupIconsByApp = true;
          groupingRespectsLayout = true;
          windowRighClickContext = true;
          label = "◦";
          occupiedBg = true;
          occupiedLabel = "⊙";
          showWindows = true;
          shown = 4;
          windowIconImage = true;
          focusedWindowBlob = true;
          windowIconGap = 0;
          windowIconSize = 30;
        };
      };

      border = {
        rounding = 25;
        thickness = 10;
      };

      dashboard = {
        mediaUpdateInterval = 500;
        showOnHover = true;
      };

      launcher = {
        actionPrefix = ">";
        dragThreshold = 50;
        vimKeybinds = false;
        enableDangerousActions = false;
        maxShown = 8;
        maxWallpapers = 9;
        specialPrefix = "@";
        useFuzzy = {
          apps = false;
          actions = false;
          schemes = false;
          variants = false;
          wallpapers = false;
        };
        showOnHover = false;
      };

      lock.recolourLogo = false;

      notifs = {
        actionOnClick = false;
        clearThreshold = 0.3;
        defaultExpireTimeout = 5000;
        expandThreshold = 20;
        expire = false;
      };

      osd = {
        enabled = true;
        enableBrightness = true;
        enableMicrophone = true;
        hideDelay = 2000;
      };

      paths = {
        mediaGif = "root:/assets/bongocat.gif";
        sessionGif = "root:/assets/kurukuru.gif";
        wallpaperDir = "~/Pictures/Wallpapers";
      };

      services = {
        audioIncrement = 0.1;
        defaultPlayer = "Spotify";
        gpuType = "";
        playerAliases = [
          { from = "com.github.th_ch.youtube_music"; to = "YT Music"; }
        ];
        weatherLocation = "";
        useFahrenheit = false;
        useTwelveHourClock = false;
        smartScheme = true;
        visualiserBars = 45;
      };

      session = {
        dragThreshold = 30;
        vimKeybinds = false;
        commands = {
          logout = [ "loginctl" "terminate-user" "" ];
          shutdown = [ "systemctl" "poweroff" ];
          hibernate = [ "systemctl" "hibernate" ];
          reboot = [ "systemctl" "reboot" ];
        };
      };
    };
  };

  # ===== Foot =====
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12";
        pad = "8x8";
      };
      "colors-dark" = {
        alpha = "0.5";
        background = "2d3a5c";
        foreground = "cfe4ff";
        regular0 = "0a0e1a";
        regular1 = "e88388";
        regular2 = "a8cc8c";
        regular3 = "dbab79";
        regular4 = "71bef2";
        regular5 = "d290e4";
        regular6 = "66c2cd";
        regular7 = "cfe4ff";
        bright0 = "475266";
        bright1 = "f09a97";
        bright2 = "b6d7a8";
        bright3 = "f0c896";
        bright4 = "9ad0ff";
        bright5 = "e3a8f0";
        bright6 = "8fd4de";
        bright7 = "ffffff";
      };
      key-bindings = {
        clipboard-copy = "Control+c";
        clipboard-paste = "Control+v";
      };
      cursor = {
        style = "beam";
        blink = "yes";
      };
    };
  };
  # ===== Обои =====
  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Wallpaper engine";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.linux-wallpaperengine}/bin/linux-wallpaperengine --fps 30 --screen-root HDMI-A-1 --screen-root DP-1 2876210462";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ===== Автолок (caelestia lock screen) =====
  # caelestia-shell's own lock (modules/lock) only reacts to its IPC call,
  # not to loginctl lock-session, so idle-based locking needs its own
  # daemon calling that IPC directly.
  systemd.user.services.idle = {
    Unit = {
      Description = "Idle daemon (auto-lock via caelestia)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = ''${pkgs.swayidle}/bin/swayidle -w timeout 300 "${caelestiaShellPkg}/bin/caelestia-shell ipc call lock lock" before-sleep "${caelestiaShellPkg}/bin/caelestia-shell ipc call lock lock"'';
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
  # ===== Starship =====
  programs.starship = {
    enable = true;
    settings = {
      format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration\n$character";
      username = {
        style_user = "bold green";
        style_root = "bold red";
        format = "[$user]($style)";
        show_always = true;
      };
      hostname = {
        format = "[@$hostname]($style):";
        style = "bold green";
      };
      directory = {
        style = "blue";
        format = "[$path]($style) ";
        truncation_length = 3;
      };
      git_branch = {
        symbol = "🌱 ";
        format = "[$symbol$branch]($style) ";
      };
      nix_shell = {
        symbol = "❄️ ";
        format = "[$symbol$state]($style) ";
        disabled = false;
      };
      cmd_duration = {
        min_time = 500;
        format = "took [$duration]($style) ";
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  # ===== Icons =====
  # Fixes blank/checkerboard icons (blueman tray menu, caelestia's media
  # widget app icons, etc) — nothing was telling GTK/Qt apps which icon
  # theme to actually use.
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # Qt apps (caelestia-shell is Qt6/QML) don't read GTK icon-theme settings
  # on their own -- this tells Qt to bridge through GTK's theme/icon config.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # ===== Git =====
  programs.git = {
    enable = true;
    userName = "artemsym";
    userEmail = "artemsym@users.noreply.github.com";
  };

  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Hyprland Polkit Agent";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.home-manager.enable = true;
}
