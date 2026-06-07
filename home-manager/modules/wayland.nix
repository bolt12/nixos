# Centralized Wayland environment variables module
{ lib, ... }:
{
  home.sessionVariables = {

    # Core Wayland variables
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "sway";

    # Wayland backend selection for various toolkits
    SDL_VIDEODRIVER = "wayland"; # SDL applications (games, media)
    QT_QPA_PLATFORM = "wayland"; # Qt applications
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1"; # Remove Qt window decorations (handled by compositor)

    # EFL/Elementary toolkit support
    ECORE_EVAS_ENGINE = "wayland_egl"; # EFL applications
    ELM_ENGINE = "wayland_egl"; # Elementary applications

    # Browser optimizations
    MOZ_ENABLE_WAYLAND = "1"; # Firefox/Mozilla Wayland support
    MOZ_DISABLE_RDD_SANDBOX = "1"; # Fix some Firefox rendering issues
    NIXOS_OZONE_WL = "1"; # Chrome/Chromium Wayland support

    # Qt theming follows GTK
    QT_QPA_PLATFORMTHEME = "gtk3";

    # EDITOR/VISUAL intentionally live in users/bolt/home.nix (the base
    # config imported by every bolt variant, headless included) — not here,
    # where they'd only cover desktop sessions and shadow the base value.
  };
}
