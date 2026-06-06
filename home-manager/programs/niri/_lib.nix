{
  # Uniform corner radius: `cornerRadius 10.0` → all four corners at 10px.
  # niri-flake types these as floats, so pass a float literal (e.g. 10.0).
  cornerRadius = r: {
    top-left = r;
    top-right = r;
    bottom-left = r;
    bottom-right = r;
  };

  # Soft, subtle drop shadow shared by windows and layer-shell surfaces.
  # Tuned for a cosy look on the X1 iGPU: large softness, no spread, gentle
  # downward offset. Semi-transparent black so it reads on the dark wallpaper.
  softShadow = {
    enable = true;
    softness = 30.0;
    spread = 0.0;
    offset = {
      x = 0.0;
      y = 6.0;
    };
    draw-behind-window = false;
    color = "#00000055";
  };
}
