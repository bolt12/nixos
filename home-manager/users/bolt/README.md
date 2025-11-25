# Bolt's Headless Configuration

This configuration is designed for the **ninho server** (headless environment).

## Features

- **Profiles**: system-tools, development, specialized
- **No Desktop**: Excludes Sway, Waybar, and other GUI applications
- **Development Tools**: Full Haskell, Agda, Lean, Arduino toolchains
- **Shell**: Bash with custom prompt and git integration

## Usage

This configuration is automatically applied when the ninho server rebuilds:

```bash
sudo nixos-rebuild switch --flake .#ninho-nixos
```

Or test standalone (requires standalone homeConfigurations in flake.nix):

```bash
home-manager switch --flake .#bolt
```

## Customization

User-specific data (bash aliases, git config) is in `user-data.nix`.

## Relationship to bolt-with-de

The `bolt-with-de` configuration **imports this file as a base** and adds desktop components. This ensures zero redundancy between headless and desktop configurations.
