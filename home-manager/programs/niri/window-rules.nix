{ ... }:

let
  inherit (import ./_lib.nix) cornerRadius softShadow;
in
{
  programs.niri.settings.window-rules = [
    # Cosy baseline for every window: rounded corners + a soft drop shadow.
    # `clip-to-geometry` makes client content respect the rounded corners.
    # Later, more specific rules below still override per-app as needed.
    {
      geometry-corner-radius = cornerRadius 10.0;
      clip-to-geometry = true;
      shadow = softShadow;
    }
    # Gently dim unfocused windows so the active column stands out. Subtle
    # enough not to feel like a modal overlay (0.92, not the typical 0.8).
    {
      matches = [ { is-active = false; } ];
      opacity = 0.92;
    }
    {
      matches = [
        { app-id = "^nm-connection-editor$"; }
        { title = "^(?:Open|Save) (?:File|Folder|As)"; }
      ];
      open-floating = true;
    }
    {
      matches = [ { app-id = "^pwvucontrol$"; } ];
      open-floating = true;
      default-column-width.fixed = 800;
      default-window-height.fixed = 600;
    }
    {
      matches = [ { app-id = "^blueman-manager$"; } ];
      open-floating = true;
      default-column-width.fixed = 600;
      default-window-height.fixed = 400;
    }
    {
      matches = [
        {
          app-id = "^firefox$";
          title = "^Picture-in-Picture$";
        }
      ];
      open-floating = true;
      default-column-width.fixed = 480;
    }
    # Mask sensitive apps from screencast/screen-share streams. Visible to
    # you locally; painted black on captures via `block-out-from`.
    {
      matches = [
        { app-id = "^org\\.keepassxc\\.KeePassXC$"; }
        { app-id = "^Bitwarden$"; }
        { app-id = "^1Password$"; }
        { app-id = "^Signal$"; }
        { app-id = "^org\\.telegram\\.desktop$"; }
        { app-id = "^discord$"; }
        { app-id = "^thunderbird$"; }
      ];
      block-out-from = "screencast";
    }
  ];
}
