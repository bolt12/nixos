nix-config
==========

My current - and always evolving - NixOS configuration files, home-manager, neovim, etc.

![desktop](imgs/desktop.png)

![desktop-1](imgs/desktop-1.png)

## What is Nix/NixOS?

**Nix** is a purely functional package manager, and **NixOS** is a Linux distribution built on top of it. Unlike traditional package managers that mutate system state, Nix treats packages as immutable values in a pure functional language.

### Why Nix? A Functional Programmer's Perspective

If you value **functional programming principles**, Nix will feel like home:

#### Immutability
- Packages are never modified after installation - they're **immutable values**
- Each package is stored in `/nix/store/` with a cryptographic hash: `/nix/store/abc123-package-1.2.3/`
- Installing a new version doesn't overwrite the old one - both coexist peacefully
- No more "it works on my machine" - if the hash matches, the package is identical

#### Determinism
- **Reproducible builds**: Same inputs → Same outputs, always
- Package definitions are pure functions: `package = f(dependencies, source, buildScript)`
- No hidden global state, no implicit dependencies
- Rollbacks are instant - just switch to a previous generation's closure

#### Referential Transparency
- Dependencies are explicit in the derivation (Nix's "build recipe")
- No `/usr/lib` pollution - each package references its exact dependencies by hash
- Change a dependency? The hash changes, giving you a new package - old one unaffected

#### Composability
- Mix and match packages from different versions (stable, unstable, specific commits)
- Layer configurations: common base + user-specific + machine-specific
- Override packages without forking: `package.override { enableFeature = true; }`

### Development Environments: Why Everything Else Falls Short

#### The Problem with Traditional Tools

**Virtualenv/venv (Python)**:
```bash
# Global pollution, version conflicts, manual management
python -m venv myenv
source myenv/bin/activate  # Pollutes your shell
pip install requests==2.28.0  # Hope it doesn't conflict with system packages!
```
- ❌ Only isolates Python packages, not system dependencies (libssl, gcc, etc.)
- ❌ Breaks when you upgrade system Python
- ❌ Doesn't handle non-Python dependencies (postgres, redis, etc.)
- ❌ State lives in a directory you must remember to activate

**Docker**:
```dockerfile
# Heavy, slow, requires root/daemon, not reproducible
FROM ubuntu:latest  # "latest" = non-deterministic
RUN apt-get update && apt-get install -y nodejs  # which version? ¯\_(ツ)_/¯
```
- ❌ "Works on my machine" still applies (base image differences)
- ❌ Massive overhead (full OS, container runtime, daemon)
- ❌ Can't easily mix with host tools (editor, git, etc.)
- ❌ Dockerfile layer caching is fragile and non-deterministic

**asdf/mise**:
```bash
# Better, but still imperative and stateful
asdf install nodejs 18.0.0
asdf global nodejs 18.0.0  # Mutates global state
```
- ❌ Still doesn't handle system dependencies
- ❌ Installation is imperative and can fail midway
- ❌ No guarantees about reproducibility across machines

#### The Nix Way

**Declarative, Pure, Reproducible**:

Create a `shell.nix`:
```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nodejs_18      # Exact version
    postgresql_15  # Including system dependencies
    redis
    python311      # Multiple Pythons? No problem
  ];

  shellHook = ''
    export DATABASE_URL="postgresql://localhost/mydb"
    echo "Welcome to the project environment!"
  '';
}
```

Enter the environment:
```bash
nix-shell  # Downloads and activates everything, instantly
# OR
nix develop  # With flakes - even more reproducible
```

**What you get**:
- ✅ **Instant, deterministic environments**: Same hash = identical environment
- ✅ **No global pollution**: Exit the shell, environment vanishes
- ✅ **Complete isolation**: All dependencies (including system libs) are isolated
- ✅ **Composition**: Overlay environments, share common bases
- ✅ **Cross-project**: Multiple projects with conflicting dependencies? No problem
- ✅ **Garbage collected**: Unused environments are automatically cleaned up
- ✅ **Zero daemon**: No Docker daemon, no background processes

**Real example from this repo**:
```nix
# Any contributor can get the exact environment:
nix develop
# Now they have the same tools, same versions, same everything
```

### Practical Benefits

**For Users**:
- Atomic upgrades: Either everything updates or nothing does
- Instant rollbacks: Boot into previous system state from GRUB
- Multiple users, multiple environments, zero conflicts
- Test changes safely: `nixos-rebuild test` (doesn't modify boot)

**For Developers**:
- One `shell.nix` replaces: venv, rbenv, nvm, docker-compose, Makefile setup
- CI/CD is just: `nix build` - if it builds locally, it builds in CI
- Share exact environments with teammates via a single file
- No "setup instructions" doc - just `nix develop`

**For Operations**:
- Entire server config in one repo (system + users + services)
- Deploy with `nixos-rebuild switch --flake .#server`
- Rollback failed deploys: just reboot and select previous generation
- No config drift: Nix derivation = exact system state

### Why This Repository Demonstrates Nix's Power

This configuration shows Nix at its best:
- **Multiple users** (bolt, pollard) with different needs, zero conflicts
- **Multiple machines** (desktop, server, Raspberry Pi) from one repo
- **Composable configs**: bolt-with-de imports bolt + adds desktop (DRY principle)
- **Reproducible**: Clone this repo, run `nixos-rebuild`, get the exact same system
- **Type-safe**: Options module validates configuration at evaluation time

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
