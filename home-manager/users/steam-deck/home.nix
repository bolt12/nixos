{ config, pkgs, lib, inputs, ... }:

# Steam Deck home-manager configuration (standalone)
# This runs on SteamOS (non-NixOS) using home-manager standalone mode

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [];
  };

  agdaStdlibSrc = pkgs.fetchFromGitHub {
    owner = "agda";
    repo = "agda-stdlib";
    rev = "v2.0";
    sha256 = "sha256-TjGvY3eqpF+DDwatT7A78flyPcTkcLHQ1xcg+MKgCoE=";
  };

  nixops = inputs.nixops.defaultPackage.${pkgs.system};
in
{
  imports = [
    # Common base configuration
    ../../common/base.nix
    ../../common/user-options.nix

    # Program configurations
    ../../programs/agda/default.nix
    ../../programs/bash/default.nix
    ../../programs/emacs/default.nix
    ../../programs/git/default.nix
    ../../programs/neovim/default.nix

    # User-specific data
    ./user-data.nix
  ];

  # User configuration via options module
  userConfig = {
    username = "deck";
    homeDirectory = "/home/deck";
    git = {
      userName = "Armando Santos (Steam Deck)";
      userEmail = "armandoifsantos@gmail.com";
      signingKey = null;
    };
  };

  # nixGL overlay for OpenGL support on non-NixOS
  nixpkgs.overlays = [ inputs.nixgl.overlay ];

  # Nix package manager settings (Steam Deck specific)
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  home = {
    username = config.userConfig.username;
    homeDirectory = config.userConfig.homeDirectory;
    stateVersion = "23.11";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      BASH_ENV = "${config.userConfig.homeDirectory}/.bashrc";
    };

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
      "${config.userConfig.homeDirectory}/.nix-profile/bin"
    ];

    # Minimal packages for Steam Deck
    packages = with pkgs; [
      wireguard-tools  # WireGuard VPN tools
    ];

    # WireGuard setup script
    file.".local/bin/setup-wireguard.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -e

        KEYS_DIR="$HOME/.config/wireguard"
        WG_CONFIG="/etc/wireguard/wg0.conf"

        echo "=== Steam Deck WireGuard Setup ==="
        echo

        # Create keys directory
        mkdir -p "$KEYS_DIR"
        chmod 700 "$KEYS_DIR"

        # Generate keys
        if [ ! -f "$KEYS_DIR/privatekey" ]; then
          echo "Generating WireGuard keys..."
          wg genkey > "$KEYS_DIR/privatekey"
          chmod 600 "$KEYS_DIR/privatekey"
          wg pubkey < "$KEYS_DIR/privatekey" > "$KEYS_DIR/publickey"
          echo "Keys generated at $KEYS_DIR/"
          echo
        else
          echo "Keys already exist at $KEYS_DIR/"
          echo
        fi

        PRIVATE_KEY=$(cat "$KEYS_DIR/privatekey")
        PUBLIC_KEY=$(cat "$KEYS_DIR/publickey")

        echo "Your public key (add this to RPI server):"
        echo "$PUBLIC_KEY"
        echo

        # Create WireGuard config
        echo "Creating WireGuard configuration..."
        cat > "$KEYS_DIR/wg0.conf" <<EOF
        [Interface]
        Address = 10.100.0.4/24
        PrivateKey = $PRIVATE_KEY
        ListenPort = 51820

        [Peer]
        # RPI5 WireGuard Server
        PublicKey = 2OIP77a10/Fas+eCvYQNa3ixFNOq0JqZIuSk1tY/QTM=
        Endpoint = rpi-nixos.ddns.net:51820
        AllowedIPs = 10.100.0.0/24
        PersistentKeepalive = 25
        EOF

        echo "Configuration created at $KEYS_DIR/wg0.conf"
        echo
        echo "Next steps:"
        echo "1. Copy your public key above"
        echo "2. On RPI server, update system/machine/rpi/rpi5.nix:"
        echo "   Change Steam Deck peer publicKey to: $PUBLIC_KEY"
        echo "3. Rebuild RPI server: sudo nixos-rebuild switch --flake .#"
        echo "4. On Steam Deck, copy config: sudo cp $KEYS_DIR/wg0.conf $WG_CONFIG"
        echo "5. Enable WireGuard: sudo systemctl enable wg-quick@wg0"
        echo "6. Start WireGuard: sudo systemctl start wg-quick@wg0"
        echo "7. Check status: sudo wg show"
      '';
    };
  };

  # Additional programs
  programs = {
    ssh = {
      matchBlocks = {
        "rpi" = {
          hostname = "192.168.1.73";
          user = "bolt";
        };
      };
    };

    autorandr.enable = true;
    firefox.enable = true;
  };

  # No services for Steam Deck
  services = {};

  # XDG configuration for Flatpak integration
  xdg = {
    mime.enable = true;
    systemDirs.data = [
      "${config.userConfig.homeDirectory}/.nix-profile/share"
      "/nix/var/nix/profiles/default/share"
      "${config.userConfig.homeDirectory}/.local/share/flatpak/exports/share"
      "/var/lib/flatpak/exports/share"
      "/usr/local/share"
      "/usr/share"
    ];
  };
}
