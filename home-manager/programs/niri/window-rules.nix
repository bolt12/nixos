{ ... }:

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
      geometry-corner-radius = {
        top-left = 8.0;
        top-right = 8.0;
        bottom-left = 8.0;
        bottom-right = 8.0;
      };
      clip-to-geometry = true;
    }
  ];
}
