# Bolt's Headless Configuration

For the **ninho server** (headless).

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

Or activate standalone:

```bash
home-manager switch --flake .#bolt
```

## Customization

User-specific data (bash aliases, git config) is in `user-data.nix`.

## Relationship to bolt-with-de

The `bolt-with-de` configuration **imports this file as a base** and adds desktop components. This ensures zero redundancy between headless and desktop configurations.
