{ ... }:

let
  inherit (import ./_lib.nix) cornerRadius softShadow;
in
# Blur via `background-effect` is not yet typed in the niri-flake DSL (and is
# the exact path that crashed Quickshell on this iGPU), so we stick to rounded
# corners + soft shadows on layer-shell surfaces for the cosy look.
{
  programs.niri.settings.layer-rules = [
    # Launcher: rounded + floating soft shadow.
    {
      matches = [
        { namespace = "^launcher$"; }
        { namespace = "^fuzzel$"; }
      ];
      geometry-corner-radius = cornerRadius 10.0;
      shadow = softShadow;
    }
    # Notifications / control center (swaync) — match the launcher treatment.
    {
      matches = [
        { namespace = "^swaync-control-center$"; }
        { namespace = "^swaync-notification-window$"; }
      ];
      geometry-corner-radius = cornerRadius 10.0;
      shadow = softShadow;
    }
    # Waybar already draws its own rounded translucent pill in style.css; give
    # it a matching soft shadow so it floats like the windows below it.
    {
      matches = [ { namespace = "^waybar$"; } ];
      shadow = softShadow;
    }
  ];
}
