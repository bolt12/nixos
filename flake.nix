{
  description = "A flake to build my NixOS configuration";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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
    emanote.url = "github:srid/emanote/1.2.0";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    emacs-overlay.url = "github:nix-community/emacs-overlay";

    # Needed for steam-deck
    nixgl.url = "github:guibou/nixGL";

    # Neovim plugins
    haskell-tools.url = "github:MrcJkb/haskell-tools.nvim";
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
    cheatsheet-nvim = {
      type = "github";
      owner = "sudormrfbin";
      repo = "cheatsheet.nvim";
      flake = false;
    };
    haskell-snippets-nvim = {
      type = "github";
      owner = "mrcjkb";
      repo = "haskell-snippets.nvim";
      flake = false;
    };
    gh-nvim = {
      type = "github";
      owner = "ldelossa";
      repo = "gh.nvim";
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
    advanced-git-search-nvim = {
      type = "github";
      owner = "aaronhallaert";
      repo = "advanced-git-search.nvim";
      flake = false;
    };
  };

  outputs = { self
            , nixpkgs
            , home-manager
            , ... }@inputs:
    let
      system = "x86_64-linux";
    in {
      # NixOS x86 configurations
      nixosConfigurations = {
        bolt-nixos = nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {inherit inputs system;};
          modules     = [ ./system/configuration.nix ];
        };

        bolt-rpi5-sd-image = (nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";

          specialArgs = {inherit inputs;};
          modules = [ inputs.raspberry-pi-nix.nixosModules.raspberry-pi
                      inputs.raspberry-pi-nix.nixosModules.sd-image
                      ./system/machine/rpi/rpi-basic.nix
                    ];
        }).config.system.build.sdImage;
      };

      # Home Manager activation script
      homeConfigurations = {
        # SteamDeck home-manager configuration
        steam-deck = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          # Specify your home configuration modules here, for example,
          # the path to your home.nix.
          modules = [ ./home-manager/steam-deck/home.nix ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
          extraSpecialArgs = {inherit inputs;};
        };
      };

      nixopsConfigurations = {
        default = {
          inherit (inputs) nixpkgs;
          network = {
            description = "My remote machines";

            storage.legacy = {};

            # Each deployment creates a new profile generation to able to run nixops
            # rollback
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
