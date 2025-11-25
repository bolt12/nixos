# Steam Deck Configuration

This is a standalone home-manager configuration for the Steam Deck running SteamOS (non-NixOS).

## Features

- **Standalone Mode**: Uses home-manager without NixOS integration
- **nixGL Support**: OpenGL support for graphical applications
- **Flatpak Integration**: XDG directories configured for Flatpak apps
- **Minimal**: Only essential programs to avoid conflicts with SteamOS

## Usage

Activate with home-manager standalone:

```bash
home-manager switch --flake .#steam-deck
```

## Important Notes

- This configuration includes nixGL overlay for OpenGL support on non-NixOS
- XDG directories are configured to work with Flatpak
- State version is 23.11 (older than other configs due to Steam Deck SteamOS base)

## Customization

Edit `user-data.nix` to add Steam Deck-specific bash aliases or shortcuts.
