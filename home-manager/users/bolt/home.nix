{ config, lib, pkgs, inputs, system, ... }:

# Bolt's headless configuration for the ninho server
# This configuration includes development tools and specialized packages
# but excludes desktop environment components

let
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    overlays = [];
  };

  # Claude wrapper with GLM configuration
  glaude = pkgs.writeShellApplication {
    name = "glaude";
    runtimeInputs = [ ];
    text = ''
      export ANTHROPIC_BASE_URL="http://10.100.0.100:8080"
      export API_TIMEOUT_MS="3000000"
      export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000
      export ANTHROPIC_DEFAULT_OPUS_MODEL="GLM-5"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="GLM-5"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="GLM-4.5-Air"
      exec claude "$@"
    '';
  };

  # Claude wrapper with only local llm setup
  olaude-flash = pkgs.writeShellApplication {
    name = "olaude-flash";
    runtimeInputs = [ ];
    text = ''
      export ANTHROPIC_BASE_URL="http://10.100.0.100:8080"
      export API_TIMEOUT_MS="3000000"
      export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000
      export ANTHROPIC_DEFAULT_OPUS_MODEL="glm-4.7-flash-full"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="glm-4.7-flash-full"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="glm-4.7-flash-full"
      exec claude "$@"
    '';
  };

  olaude-qwen3 = pkgs.writeShellApplication {
    name = "olaude-qwen3";
    runtimeInputs = [ ];
    text = ''
      export ANTHROPIC_BASE_URL="http://10.100.0.100:8080"
      export API_TIMEOUT_MS="3000000"
      export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000
      export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen3-coder-next-full"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen3-coder-next-full"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen3-coder-next-full"
      exec claude "$@"
    '';
  };
in
{
  imports = [
    # Common base configuration
    ../../common/base.nix
    ../../common/user-options.nix

    # Package profiles (headless - no desktop/wayland)
    ../../profiles/system-tools.nix
    ../../profiles/development.nix
    ../../profiles/specialized.nix   # Agda, Lean, Arduino, etc.

    # Program configurations
    ../../programs/ai-cmd/default.nix
    ../../programs/agda/default.nix
    ../../programs/bash/default.nix
    ../../programs/emacs/default.nix
    ../../programs/git/default.nix
    ../../programs/neovim/default.nix
    ../../programs/syncthing/default.nix
    ../../programs/tmux/default.nix

    # User-specific data (git email, bash aliases, Syncthing config, etc.)
    ./user-data.nix
  ];

  # User configuration via options module
  userConfig = {
    username = "bolt";
    homeDirectory = "/home/bolt";
    git = {
      userName = "Armando Santos";
      userEmail = "armandoifsantos@gmail.com";
      signingKey = null;
    };
  };


  home = {
    username = config.userConfig.username;
    homeDirectory = config.userConfig.homeDirectory;
    stateVersion = "25.05";

    keyboard = {
      layout = "us,pt";
      options = [
        "caps:escape"
        "grp:shifts_toggle"
      ];
    };

    sessionVariables = {
      EDITOR="nvim";
      VISUAL="nvim";
    };

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
    ];

    # All packages managed through profiles
    packages = [
      glaude
      olaude-flash
      olaude-qwen3
    ];
  };

  # Additional programs (headless - no firefox, no autorandr)
  programs = {
    ssh = {
      enable = true;
      # Disable deprecated default config - explicitly set what we need
      enableDefaultConfig = false;

      matchBlocks = {
        # Default settings for all hosts (replaces deprecated defaults)
        "*" = {
          serverAliveInterval = 60;
          serverAliveCountMax = 3;
        };

        "rpi" = {
          hostname = "10.100.1.1";
          user = "bolt";
        };
        "ninho" = {
          hostname = "10.100.1.100";
          user = "bolt";
        };
      };
    };
  };

  # No desktop services for headless configuration
  services = {};
}
