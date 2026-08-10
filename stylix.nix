{ pkgs, ... }:
{
  stylix.enable = true;
  stylix.polarity = "dark";
  stylix.opacity.terminal = 0.65;
  stylix.base16Scheme = {
    base00 = "0d1117";
    base01 = "161b22";
    base02 = "21262d";
    base03 = "3d4451";
    base04 = "6e7b8b";
    base05 = "c9d1d9";
    base06 = "dbe6f2";
    base07 = "ffffff";
    base08 = "e88388";
    base09 = "dbab79";
    base0A = "d290e4";
    base0B = "a8cc8c";
    base0C = "66c2cd";
    base0D = "1f6feb";
    base0E = "7fc8ff";
    base0F = "71bef2";
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
