{ config, pkgs, ... }:
{
  home.username = "gothness";
  home.homeDirectory = "/home/gothness";
  home.stateVersion = "26.05";

  # ===== Niri =====
  xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;

  # ===== Waybar =====
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar-style.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        margin-top = 0;
        modules-left = [ "custom/firefox" "custom/vscode" "niri/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "custom/media-prev" "custom/media-eq" "custom/media-title" "custom/media-next" "pulseaudio" "network" "battery" "tray" ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "●";
            default = "○";
          };
        };

        "custom/firefox" = {
          format = "";
          on-click = "firefox";
          tooltip-format = "Firefox";
        };

        "custom/vscode" = {
          format = "󰨞";
          on-click = "code";
          tooltip-format = "VS Code";
        };

        clock = {
          format = "{:%H:%M}";
          tooltip-format = "{:%A, %d %B %Y}";
        };

        "custom/media-prev" = {
          format = "󰒮";
          on-click = "playerctl previous";
          tooltip = false;
        };

        "custom/media-eq" = {
          exec = "~/.config/waybar/scripts/cava-eq.sh";
          return-type = "";
          format = "{}";
        };

        "custom/media-title" = {
          exec = "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo ''";
          interval = 2;
          format = "{}";
          on-click = "playerctl play-pause";
          max-length = 30;
        };

        "custom/media-next" = {
          format = "󰒭";
          on-click = "playerctl next";
          tooltip = false;
        };

        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "muted";
          format-icons = {
            default = [ "" "" "" ];
          };
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        network = {
          format-wifi = "{essid} ";
          format-ethernet = "eth ";
          format-disconnected = "offline";
          tooltip-format = "{ipaddr}";
        };

        battery = {
          format = "{capacity}% {icon}";
          format-icons = [ "" "" "" "" "" ];
        };

        tray = {
          spacing = 8;
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
      ExecStart = "${pkgs.linux-wallpaperengine}/bin/linux-wallpaperengine --screen-root HDMI-A-1 --screen-root DP-1 2876210462";
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
