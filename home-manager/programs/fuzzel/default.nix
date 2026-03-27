# Fuzzel - Wayland-native application launcher (replaces wofi)
{ pkgs, ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
        terminal = "konsole";
        width = 35;
        lines = 10;
        layer = "overlay";
        prompt = "  ";
      };
      colors = {
        # Catppuccin Mocha
        background = "1e1e2edd";
        text = "cdd6f4ff";
        match = "89b4faff";
        selection = "313244ff";
        selection-text = "cdd6f4ff";
        selection-match = "89b4faff";
        border = "89b4faff";
      };
      border = {
        width = 2;
        radius = 12;
      };
    };
  };
}
