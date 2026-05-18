{ ... }:

let
  inherit (import ./_lib.nix) cornerRadius8;
in
# Blur via `background-effect` not yet typed in niri-flake DSL.
{
  programs.niri.settings.layer-rules = [
    {
      matches = [
        { namespace = "^launcher$"; }
        { namespace = "^fuzzel$"; }
      ];
      geometry-corner-radius = cornerRadius8;
    }
  ];
}
