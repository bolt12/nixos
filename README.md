nix-config
==========

My current - and always evolving - NixOS configuration files, home-manager, neovim, etc.

![desktop](imgs/desktop.png)

![desktop-1](imgs/desktop-1.png)

## Programs

The home-manager configuration contains details about all the software I use. Here's a shout-out to the ones I use the most and that are customized to my needs.

| Type           | Program      |
| :------------- | :----------: |
| Editor         | [NeoVim](https://github.com/neovim/neovim) |
| Launcher       | [Wofi](https://github.com/mikn/wofi) |
| Shell          | [Bash](https://www.gnu.org/software/bash/) |
| Status Bar     | [Waybar](https://github.com/Alexays/Waybar) |
| Terminal       | [Konsole](https://konsole.kde.org/) |
| Window Manager | [Sway](https://github.com/swaywm/sway) |

## Structure

Here is an overview of the repository structure:

```
├── flake.nix              # Main flake configuration
├── home-manager/          # Home-manager user configurations
│   ├── common/            # Shared configuration
│   │   ├── base.nix       # Common programs and settings
│   │   └── user-options.nix  # Parameterization options
│   ├── users/             # Per-user configurations
│   │   ├── bolt/          # Headless config for ninho server
│   │   ├── bolt-with-de/  # Desktop config for bolt-nixos
│   │   ├── pollard/       # Beginner-friendly config
│   │   └── steam-deck/    # Steam Deck configuration
│   ├── profiles/          # Modular package collections
│   │   ├── desktop.nix    # GUI applications
│   │   ├── development.nix # Development tools
│   │   ├── system-tools.nix # CLI utilities
│   │   ├── specialized.nix # Agda, Lean, Arduino, etc.
│   │   └── wayland.nix    # Wayland compositor packages
│   ├── programs/          # Program-specific configurations
│   │   ├── neovim/        # Neovim with plugins and LSP
│   │   ├── git/           # Git with aliases and delta
│   │   ├── bash/          # Bash with custom prompt
│   │   ├── sway/          # Sway window manager
│   │   └── ... (10+ more)
│   └── xdg/               # XDG desktop configurations
├── imgs/                  # Screenshots
├── install.sh             # Interactive installation script
└── system/                # NixOS system configurations
    ├── configuration.nix  # Main desktop/laptop config
    └── machine/           # Machine-specific configurations
        ├── ninho/         # Home server with ZFS RAID
        ├── rpi/           # Raspberry Pi configurations
        ├── x1-g8/         # ThinkPad X1 Gen 8
        └── thinkpadx200/ # ThinkPad X200
```

### Key Directories

- **`home-manager/`**: User environment configurations using home-manager
  - **`common/`**: Shared configuration and parameterization framework
  - **`users/`**: Per-user configurations (bolt, bolt-with-de, pollard, steam-deck)
  - **`profiles/`**: Modular package collections that can be mixed and matched
  - **`programs/`**: Detailed program configurations (neovim, git, sway, etc.)
- **`system/`**: NixOS system-level configurations
  - **`machine/`**: Hardware-specific configurations for different devices
- **`flake.nix`**: Main flake defining all configurations and home-manager integrations

### Configuration Architecture

This repository uses a **modular, multi-user architecture**:

1. **Common Base** (`home-manager/common/`): Shared settings across all users
2. **Profiles** (`home-manager/profiles/`): Reusable package collections
3. **User Configs** (`home-manager/users/`): Per-user configurations that compose profiles
4. **Zero Redundancy**: `bolt-with-de` imports `bolt` as base and adds desktop components

Each user has:
- `home.nix` - Main configuration file
- `user-data.nix` - Personal git config and bash aliases
- `README.md` - Usage documentation

See `home-manager/MIGRATION_SUMMARY.md` for detailed architecture documentation.

## Configurations

This repository includes multiple system and user configurations:

### NixOS Systems

| System | Architecture | Description | Users |
|--------|--------------|-------------|-------|
| **bolt-nixos** | x86_64 | Main desktop/laptop with Sway | bolt (with DE) |
| **ninho-nixos** | x86_64 | Home server with ZFS RAID | bolt, pollard |
| **bolt-rpi5** | aarch64 | Raspberry Pi 5 | - |

### Home-Manager Users

| User | Target | GUI | Description |
|------|--------|-----|-------------|
| **bolt** | ninho | No | Headless with development tools |
| **bolt-with-de** | bolt-nixos | Yes (Sway) | Full desktop environment |
| **pollard** | ninho | No | Beginner-friendly with learning resources |
| **steam-deck** | Steam Deck | Gaming | Minimal standalone configuration |

## Usage

### System Rebuilds (NixOS)

```shell
# Rebuild main desktop/laptop (bolt-nixos)
sudo nixos-rebuild switch --flake .#bolt-nixos

# Rebuild home server (ninho-nixos)
sudo nixos-rebuild switch --flake .#ninho-nixos

# Test configuration before applying
sudo nixos-rebuild test --flake .#ninho-nixos
```

### Standalone Home-Manager

```shell
# Apply user configuration independently
home-manager switch --flake .#bolt
home-manager switch --flake .#pollard
home-manager switch --flake .#steam-deck
```

### Interactive Installation Script

The repository includes an interactive installation script:

```shell
./install.sh
```

This will present a menu of available configurations to apply.

## Install

On a fresh NixOS installation, run the following commands:

```shell
mkdir DELETE_ME && cd DELETE_ME
nix-shell --run \
  "wget -c https://github.com/bolt12/nixos/archive/master.tar.gz && tar --strip-components=1 -xvf master.tar.gz" \
  -p wget s-tar
chmod +x install.sh && ./install.sh
```

## Adding a New User

To add a new user configuration:

1. Create a new directory: `home-manager/users/newuser/`
2. Copy a template:
   ```shell
   cp -r home-manager/users/pollard/* home-manager/users/newuser/
   ```
3. Edit `home-manager/users/newuser/home.nix`:
   - Update `userConfig.username`, `homeDirectory`
   - Choose which profiles to import
4. Edit `home-manager/users/newuser/user-data.nix`:
   - Set git user name and email
   - Add personal bash aliases
5. Add to `flake.nix`:
   ```nix
   homeConfigurations.newuser = home-manager.lib.homeManagerConfiguration {
     pkgs = nixpkgs.legacyPackages.${system};
     modules = [ ./home-manager/users/newuser/home.nix ];
     extraSpecialArgs = { inherit inputs system; };
   };
   ```
6. Add to system configuration if using NixOS-integrated home-manager

See `home-manager/MIGRATION_SUMMARY.md` for detailed architecture documentation.
