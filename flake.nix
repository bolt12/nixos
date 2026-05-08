{
  description = "A flake to build my NixOS configuration";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://niri.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
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
      url = "github:danth/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
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

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      colmena,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};

      # Centralized constants (ports, IPs, storage paths, …).
      constants = import ./system/common/constants.nix { inherit lib; };

      # Single source of truth for the unstable overlay; reused for
      # NixOS systems (via overlays.nix) and standalone homeConfigurations.
      unstableOverlay = import ./system/common/unstable-overlay.nix { inherit inputs; };

      # Build a NixOS system with the conventional specialArgs and, optionally,
      # standalone-style home-manager wiring. Keeping this small on purpose:
      # bolt-rpi5-sd-image and the ninho-internal HM wiring don't fit and
      # stay separate.
      mkSystem =
        {
          modules,
          system ? "x86_64-linux",
          hmUser ? null,
          hmModule ? null,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs system constants; };
          modules =
            modules
            ++ lib.optionals (hmUser != null) [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = { inherit inputs system constants; };
                  users.${hmUser}.imports = [ hmModule ];
                };
              }
            ];
        };

      # Wrap a one-line invocation as a `nix run`-able app.
      mkApp = name: description: text: {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            inherit name text;
          }
        }/bin/${name}";
        meta.description = description;
      };
    in
    {
      # NixOS x86 configurations
      nixosConfigurations = {
        bolt-nixos = mkSystem {
          modules = [
            ./system/configuration.nix
            ./system/common/overlays.nix
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
            inputs.niri.nixosModules.niri
          ];
        };

        # SD-image build is structurally different (different return value,
        # aarch64, no constants) so it stays out of mkSystem.
        bolt-rpi5-sd-image =
          (nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              inputs.raspberry-pi-nix.nixosModules.raspberry-pi
              inputs.raspberry-pi-nix.nixosModules.sd-image
              ./system/machine/rpi/rpi-basic.nix
            ];
          }).config.system.build.sdImage;

        ninho-nixos = mkSystem {
          modules = [
            ./system/machine/ninho/configuration.nix
            ./system/common/overlays.nix
          ];
        };

        bolt-x200 = mkSystem {
          modules = [
            ./system/machine/thinkpadx200/default.nix
            ./system/common/overlays.nix
          ];
          hmUser = "bolt";
          hmModule = ./home-manager/users/bolt-with-de/home.nix;
        };
      };

      # Standalone home-manager activations.
      # `pkgsFor` exposes pkgs.unstable.* the same way NixOS systems do.
      homeConfigurations =
        let
          pkgsFor =
            sys:
            import nixpkgs {
              system = sys;
              config.allowUnfree = true;
              overlays = [ unstableOverlay ];
            };
        in
        {
          # Bolt headless configuration for ninho server
          bolt = home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsFor system;
            modules = [ ./home-manager/users/bolt/home.nix ];
            extraSpecialArgs = { inherit inputs system constants; };
          };

          # Bolt desktop configuration for bolt-nixos
          bolt-with-de = home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsFor system;
            modules = [ ./home-manager/users/bolt-with-de/home.nix ];
            extraSpecialArgs = { inherit inputs system constants; };
          };

          # Pollard configuration for ninho server
          pollard = home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsFor system;
            modules = [ ./home-manager/users/pollard/home.nix ];
            extraSpecialArgs = { inherit inputs system constants; };
          };

          # SteamDeck home-manager configuration
          steam-deck = home-manager.lib.homeManagerConfiguration {
            pkgs = pkgsFor "x86_64-linux";
            modules = [ ./home-manager/users/steam-deck/home.nix ];
            extraSpecialArgs = {
              inherit inputs constants;
              system = "x86_64-linux";
            };
          };
        };

      # Colmena deployment configuration
      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          specialArgs = { inherit inputs constants; };
        };

        # RPI 5 deployment target
        rpi-5 =
          {
            name,
            nodes,
            pkgs,
            ...
          }:
          {
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

      # Formatter for `nix fmt`
      formatter.${system} = pkgs.nixfmt-rfc-style;

      # Build checks for `nix flake check`
      checks.${system} = {
        ninho = self.nixosConfigurations.ninho-nixos.config.system.build.toplevel;
        bolt-nixos = self.nixosConfigurations.bolt-nixos.config.system.build.toplevel;
      };

      # `nix develop` — tools used while editing this repo.
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.nixfmt-rfc-style # `nix fmt`
          pkgs.statix # lints
          pkgs.deadnix # dead-code finder
          pkgs.nil # LSP for editors that want it
          pkgs.colmena # rpi deploys (disambiguates from the `colmena` flake input)
          pkgs.git
        ];
      };

      # `nix run .#<name>` shortcuts for common operations.
      apps.${system} = {
        deploy-ninho = mkApp "deploy-ninho" "Switch ninho-nixos to the current flake (sudo)." ''
          exec sudo nixos-rebuild switch --flake .#ninho-nixos "$@"
        '';
        deploy-bolt = mkApp "deploy-bolt" "Switch bolt-nixos to the current flake (sudo)." ''
          exec sudo nixos-rebuild switch --flake .#bolt-nixos "$@"
        '';
        dry-ninho = mkApp "dry-ninho" "Dry-build ninho-nixos without activating." ''
          exec nixos-rebuild dry-build --flake .#ninho-nixos "$@"
        '';
        dry-bolt = mkApp "dry-bolt" "Dry-build bolt-nixos without activating." ''
          exec nixos-rebuild dry-build --flake .#bolt-nixos "$@"
        '';
        fmt = mkApp "fmt" "Format every Nix file via nixfmt-rfc-style." ''
          exec nix fmt -- "$@"
        '';
        update = mkApp "update" "Update flake.lock to the latest pinned inputs." ''
          exec nix flake update "$@"
        '';
      };
    };
}
