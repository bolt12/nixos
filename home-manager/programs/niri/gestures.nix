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
    # Top-left → toggle-overview is hardcoded in niri itself; per-corner
    # actions aren't exposed in niri's KDL grammar (and therefore not in
    # niri-flake's DSL) as of 26.04. Re-evaluate if upstream adds them.
    hot-corners.enable = true;
  };
}
