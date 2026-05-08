{ ... }:

{
  programs.niri.settings.gestures = {
    dnd-edge-view-scroll = {
      trigger-width = 30;
      max-speed = 1500.0;
    };
    dnd-edge-workspace-switch = {
      trigger-height = 50;
      max-speed = 1500.0;
    };
    hot-corners.enable = true;
  };
}
