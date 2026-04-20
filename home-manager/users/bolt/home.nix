{
  config,
  lib,
  pkgs,
  inputs,
  system,
  constants,
  ...
}:

# Bolt's headless configuration for the ninho server
# This configuration includes development tools and specialized packages
# but excludes desktop environment components

let
  llamaswapUrl = "http://${constants.network.ninho.vpnIp}:${toString constants.ports.llamaswap}";

  # Wraps `claude` to route through ninho's llama-swap endpoint with a chosen model.
  #  - model:        used for Opus and Sonnet slots
  #  - haikuModel:   used for Haiku slot (defaults to `model`)
  #  - haikuEnvVar:  if set, lets that env var override haikuModel at run-time
  mkClaudeWrapper = { name, model, haikuModel ? model, haikuEnvVar ? null }:
    let
      haikuExpr =
        if haikuEnvVar == null
        then haikuModel
        else "\${${haikuEnvVar}:-${haikuModel}}";
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ ];
      text = ''
        export ANTHROPIC_BASE_URL="${llamaswapUrl}"
        export API_TIMEOUT_MS="3000000"
        export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000
        export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
        export ANTHROPIC_DEFAULT_OPUS_MODEL="${model}"
        export ANTHROPIC_DEFAULT_SONNET_MODEL="${model}"
        export ANTHROPIC_DEFAULT_HAIKU_MODEL="${haikuExpr}"
        exec claude "$@"
      '';
    };

  glaude                 = mkClaudeWrapper { name = "glaude";                 model = "GLM-5";             haikuModel = "GLM-4.5-Air"; };
  olaude-qwen3-5-27B     = mkClaudeWrapper { name = "olaude-qwen3-5-27B";     model = "qwen3.5-27B-full";     haikuEnvVar = "OLAUDE_HAIKU"; };
  olaude-qwen3-6-35B-A3B = mkClaudeWrapper { name = "olaude-qwen3-6-35B-A3B"; model = "qwen3.6-35B-A3B-full"; haikuEnvVar = "OLAUDE_HAIKU"; };
  olaude-gemma-4-26B-A4B = mkClaudeWrapper { name = "olaude-gemma-4-26B-A4B"; model = "gemma-4-26B-A4B";      haikuEnvVar = "OLAUDE_HAIKU"; };

  # Pi coding agent wrapper for Ninho local models
  pi-local = pkgs.writeShellApplication {
    name = "pi-local";
    runtimeInputs = [ ];
    text = ''
      exec pi --provider ninho --model "''${PI_LOCAL_MODEL:-gemma-4-26B-A4B}" "$@"
    '';
  };

  # Pi coding agent wrapper for GLM via Ninho (Anthropic-compatible API via z.ai)
  pi-glm = pkgs.writeShellApplication {
    name = "pi-glm";
    runtimeInputs = [ ];
    text = ''
      exec pi --provider ninho-glm --model "''${PI_GLM_MODEL:-GLM-4.7}" "$@"
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
    ../../profiles/specialized.nix # Agda, Lean, Arduino, etc.

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
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
    ];

    # All packages managed through profiles
    packages = [
      glaude
      olaude-qwen3-5-27B
      olaude-qwen3-6-35B-A3B
      olaude-gemma-4-26B-A4B
      pi-local
      pi-glm
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
          hostname = constants.network.rpi.vpnIp;
          user = "bolt";
        };
        "ninho" = {
          hostname = constants.network.ninho.vpnIp;
          user = "bolt";
        };
      };
    };
  };

  # Emanote journal server (user-level — bolt's personal data)
  systemd.user.services.emanote = {
    Unit = {
      Description = "Emanote journal server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${
        inputs.emanote.packages.${system}.default
      }/bin/emanote --layers \"%h/journal\" run --no-ws --host=0.0.0.0 --port=${toString constants.ports.emanote}";
      Restart = "always";
      RestartSec = "10";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # No desktop services for headless configuration
  services = { };
}
