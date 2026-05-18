{ config, lib, ... }:

let
  spring = stiffness: {
    kind.spring = {
      damping-ratio = 1.0;
      inherit stiffness;
      epsilon = 0.0001;
    };
  };

  # Convert a "#rrggbb" base16 colour into a GLSL-friendly "r, g, b" string
  # of normalised floats (e.g. "0.796, 0.651, 0.969").
  hexToGlsl =
    hex:
    let
      h = lib.toLower (lib.removePrefix "#" hex);
      digitVal = {
        "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4;
        "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
        "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
      };
      pair = i:
        digitVal.${builtins.substring i 1 h} * 16
        + digitVal.${builtins.substring (i + 1) 1 h};
      norm = n: builtins.toString ((1.0 * n) / 255.0);
    in
    "${norm (pair 0)}, ${norm (pair 2)}, ${norm (pair 4)}";

  # base0E (mauve in Mocha) → base0C (teal/sky in Mocha). Falls back to
  # safe defaults if stylix isn't enabled (which won't happen on this host,
  # but keeps the shader robust if this module is ever reused).
  palette =
    if config.stylix.enable or false then
      config.lib.stylix.colors.withHashtag
    else
      {
        base0E = "#cba6f7";
        base0C = "#89dceb";
      };

  tintShader = path:
    builtins.replaceStrings
      [ "@TINT_FROM@" "@TINT_TO@" ]
      [ (hexToGlsl palette.base0E) (hexToGlsl palette.base0C) ]
      (builtins.readFile path);

  closeShader = tintShader ./shaders/window-close.glsl;
  openShader = tintShader ./shaders/window-open.glsl;
in
{
  programs.niri.settings.animations = {
    enable = true;
    slowdown = 1.0;

    workspace-switch = spring 1000;
    horizontal-view-movement = spring 800;
    overview-open-close = spring 800;
    window-movement = spring 800;
    window-resize = spring 800;

    window-open = {
      kind.easing = {
        duration-ms = 150;
        curve = "ease-out-expo";
      };
      custom-shader = openShader;
    };
    window-close = {
      kind.easing = {
        duration-ms = 250;
        curve = "ease-out-quad";
      };
      custom-shader = closeShader;
    };

    config-notification-open-close.enable = true;
  };
}
