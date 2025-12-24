{
  description = "A flake to build my NixOS configuration";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixops = {
      url = "github:NixOS/nixops";
    };

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    # Pin emanote to version 1.4.0.0
    emanote = {
      url = "github:srid/emanote/1.4.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    emacs-overlay.url = "github:nix-community/emacs-overlay";

    # kimai-client.url = "git+ssh://git@gitlab.well-typed.com/well-typed/kimai-client.git?ref=bolt12/patch";

    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
    };

    # Needed for steam-deck
    nixgl.url = "github:guibou/nixGL";

    # Neovim plugins
    vim-bujo = {
      type = "github";
      owner = "vuciv";
      repo = "vim-bujo";
      flake = false;
    };
    neoscroll-nvim = {
      type = "github";
      owner = "karb94";
      repo = "neoscroll.nvim";
      flake = false;
    };
    vim-silicon = {
      type = "github";
      owner = "segeljakt";
      repo = "vim-silicon";
      flake = false;
    };
    venn-nvim = {
      type = "github";
      owner = "jbyuki";
      repo = "venn.nvim";
      flake = false;
    };
    HighStr-nvim = {
      type = "github";
      owner = "Pocco81";
      repo = "HighStr.nvim";
      flake = false;
    };
    telescope-ui-select-nvim = {
      type = "github";
      owner = "nvim-telescope";
      repo = "telescope-ui-select.nvim";
      flake = false;
    };
    cornelis = {
      url = "github:isovector/cornelis";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    e-ink-nvim = {
      type = "github";
      owner = "alexxGmZ";
      repo = "e-ink.nvim";
      flake = false;
    };
  };

  outputs = { self
            , nixpkgs
            , home-manager
            , ... }@inputs:
    let
      system = "x86_64-linux";
      # Import centralized constants
      constants = import ./system/common/constants.nix { lib = nixpkgs.lib; };
    in {
      # NixOS x86 configurations
      nixosConfigurations = {
        bolt-nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {inherit inputs system constants;};
          modules = [
            ./system/configuration.nix
            ./system/common/overlays.nix
          ];
        };

        bolt-rpi5-sd-image = (nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {inherit inputs;};
          modules = [
            inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            inputs.raspberry-pi-nix.nixosModules.sd-image
            ./system/machine/rpi/rpi-basic.nix
          ];
        }).config.system.build.sdImage;

        ninho-nixos = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {inherit inputs system constants;};
          modules = [
            ./system/machine/ninho/configuration.nix
            ./system/common/overlays.nix
          ];
        };
      };

      # Home Manager activation script
      homeConfigurations = {
        # Bolt headless configuration for ninho server
        bolt = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./home-manager/users/bolt/home.nix ];
          extraSpecialArgs = { inherit inputs system; };
        };

        # Bolt desktop configuration for bolt-nixos
        bolt-with-de = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./home-manager/users/bolt-with-de/home.nix ];
          extraSpecialArgs = { inherit inputs system; };
        };

        # Pollard configuration for ninho server
        pollard = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./home-manager/users/pollard/home.nix ];
          extraSpecialArgs = { inherit inputs system; };
        };

        # SteamDeck home-manager configuration
        steam-deck = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [ ./home-manager/users/steam-deck/home.nix ];
          extraSpecialArgs = { inherit inputs; };
        };
      };

      nixopsConfigurations = {
        default = {
          inherit (inputs) nixpkgs;
          network = {
            description = "My remote machines";
            storage.legacy = {};
            enableRollback = true;
          };

          # Common configuration shared between all servers
          defaults = { ... }: {
            imports = [
              inputs.raspberry-pi-nix.nixosModules.raspberry-pi
              ./system/machine/rpi/hardware-configuration.nix
              ./system/machine/rpi/rpi-basic.nix
              ./system/machine/rpi/rpi5.nix
            ];
          };

          # Server definitions
          rpi-5 = { ... }: {
            # Augment standard NixOS module arguments.
            _module.args = {
              inherit inputs;
            };

            # Says we are going to deploy to an already existing NixOS machine
            deployment.targetHost = "192.168.1.110";

            imports = [
              ./system/machine/rpi/rpi5.nix
            ];

            nixpkgs.localSystem = {
              system = "aarch64-linux";
              config = "aarch64-unknown-linux-gnu";
              hostPlatform = "aarch64-linux";
            };
          };
        };
      };
    };
  }
