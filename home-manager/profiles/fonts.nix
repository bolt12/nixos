# Fonts profile, system-wide typography for the desktop user.
# Imported alongside `desktop.nix`; lifted out so headless users (or forks
# that prefer a thinner font set) can opt out without editing desktop apps.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    dejavu_fonts # Standard fonts
    noto-fonts-color-emoji # Emoji support
    font-awesome # Icon font
    hack-font # Monospace programming font
    inconsolata # Monospace font
    inter # Clean UI sans-serif (Stylix sansSerif / waybar UI)
    liberation_ttf # Microsoft font alternatives
    material-icons # Material Design icons
    nerd-fonts.fira-code # Programming font with ligatures
    nerd-fonts.jetbrains-mono # JetBrains programming font
    noto-fonts # Google Noto fonts
    noto-fonts-cjk-sans # CJK language support
    open-dyslexic # Dyslexia-friendly font
    open-sans # Clean sans-serif font
    siji # Icon font for status bars
    terminus_font # Bitmap terminal font
    ubuntu-classic # Ubuntu font family
    unifont # Unicode font
    xits-math # Mathematical typesetting
  ];
}
