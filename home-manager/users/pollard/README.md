# Pollard's Configuration

This configuration is designed for the **ninho server** with a focus on learning NixOS and ZFS.

## Features

- **Minimal Package Set**: Core system tools and development essentials
- **Learning Resources**: tldr, cheat, man pages with search
- **Modern CLI Tools**: bat, eza, fd, ripgrep (easier than traditional tools)
- **ZFS Tools**: Complete ZFS management toolchain

## NixOS Learning Aliases

- `nix-help` - Open NixOS manual
- `nix-search <package>` - Search for packages
- `hm-help` - Open home-manager manual

## Usage

This configuration is automatically applied when the ninho server rebuilds:

```bash
sudo nixos-rebuild switch --flake .#ninho-nixos
```

Or test standalone:

```bash
home-manager switch --flake .#pollard
```

## Customization

Edit `user-data.nix` to add personal bash aliases or modify git configuration.

## Tips for Getting Started

1. Use `tldr <command>` instead of `man <command>` for quick examples
2. Use `bat` instead of `cat` for syntax-highlighted file viewing
3. Use `eza -la` instead of `ls -la` for better file listings
4. Use `fd <pattern>` instead of `find` for simpler file searching
5. Check pool status regularly with `pool-status`
6. Review ZFS snapshots with `zfs-snaps`
