{
  description = "A flake to build my NixOS configuration";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    # Pin emanote to version 1.4.0.0
    emanote = {
      url = "github:srid/emanote/1.4.0.0";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    emacs-overlay.url = "github:nix-community/emacs-overlay";

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
    };

    # llama-swap - latest release for model swapping
    llama-swap = {
      url = "github:mostlygeek/llama-swap/v182";
      flake = false;
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
    llama-vim = {
      type = "github";
      owner = "ggml-org";
      repo = "llama.vim";
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
            , colmena
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
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
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

        bolt-x200 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs system constants; };
          modules = [
            ./system/machine/thinkpadx200/default.nix
            ./system/common/overlays.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = { inherit inputs system; };
                users.bolt = { nixpkgs, ... }: {
                  imports = [ ./home-manager/users/bolt-with-de/home.nix ];
                };
              };
            }
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
          extraSpecialArgs = { inherit inputs; system = "x86_64-linux"; };
        };
      };

      # Colmena deployment configuration
      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          specialArgs = { inherit inputs; };
        };

        # RPI 5 deployment target
        rpi-5 = { name, nodes, pkgs, ... }: {
          deployment = {
            targetHost = "192.168.1.110";
            targetUser = "root";
            # Build locally via QEMU binfmt emulation (not cross-compilation)
            buildOnTarget = false;
            allowLocalDeployment = false;
          };

          imports = [
            inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            ./system/machine/rpi/hardware-configuration.nix
            ./system/machine/rpi/rpi-basic.nix
            ./system/machine/rpi/rpi5.nix
          ];

          nixpkgs.system = "aarch64-linux";
        };
      };
    };
  }
