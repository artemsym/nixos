{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.polarity = "dark";
  stylix.opacity.terminal = 0.65;
  stylix.base16Scheme = {
    base00 = "0d1117"; # фон (тёмный, как у waybar window)
    base01 = "161b22";
    base02 = "21262d";
    base03 = "3d4451"; # inactive-color из niri focus-ring
    base04 = "6e7b8b"; # workspaces inactive
    base05 = "c9d1d9"; # основной текст (waybar color)
    base06 = "dbe6f2"; # clock text
    base07 = "ffffff";
    base08 = "e88388"; # regular1 из foot
    base09 = "dbab79"; # regular3
    base0A = "d290e4"; # regular5
    base0B = "a8cc8c"; # regular2
    base0C = "66c2cd"; # regular6
    base0D = "1f6feb"; # focus-ring active-color / основной акцент
    base0E = "7fc8ff"; # workspaces active
    base0F = "71bef2"; # regular4
  };

  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.noto-fonts;
      name = "Noto Sans";
    };
  };

  stylix.cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
