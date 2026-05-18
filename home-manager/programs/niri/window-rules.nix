{ ... }:

let
  inherit (import ./_lib.nix) cornerRadius8;
in
{
  programs.niri.settings.window-rules = [
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
    # Blur via `background-effect` not yet typed in niri-flake DSL.
    {
      matches = [ { app-id = "^org\\.kde\\.konsole$"; } ];
      geometry-corner-radius = cornerRadius8;
      clip-to-geometry = true;
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
    {
      matches = [ { is-floating = true; } ];
      geometry-corner-radius = cornerRadius8;
      clip-to-geometry = true;
    }
  ];
}
