{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.lib.stylix.colors) withHashtag;
in
{
  home.packages = with pkgs.unstable; [
    noctalia-shell
    quickshell
  ];

  # Keep Noctalia tied to the niri session lifecycle (dies with niri,
  # restarts on niri restart) instead of running as a standalone user unit.
  programs.niri.settings.spawn-at-startup = lib.mkAfter [
    { argv = [ "noctalia-shell" ]; }
  ];

  # Non-recursive xdg.configFile leaves the rest of ~/.config/noctalia-shell/
  # writable so Noctalia's own settings UI can persist user changes.
  xdg.configFile."noctalia-shell/colors.json".text = builtins.toJSON {
    name = "Stylix";
    base = withHashtag.base00;
    mantle = withHashtag.base01;
    crust = withHashtag.base00;
    surface0 = withHashtag.base02;
    surface1 = withHashtag.base03;
    text = withHashtag.base05;
    subtext0 = withHashtag.base04;
    overlay0 = withHashtag.base04;
    blue = withHashtag.base0D;
    lavender = withHashtag.base07;
    sapphire = withHashtag.base0C;
    sky = withHashtag.base0C;
    teal = withHashtag.base0C;
    green = withHashtag.base0B;
    yellow = withHashtag.base0A;
    peach = withHashtag.base09;
    maroon = withHashtag.base08;
    red = withHashtag.base08;
    mauve = withHashtag.base0E;
    pink = withHashtag.base0F;
  };
}
