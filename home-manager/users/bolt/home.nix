{
  config,
  lib,
  pkgs,
  constants,
  ...
}:

# Bolt's headless configuration for the ninho server
# This configuration includes development tools and specialized packages
# but excludes desktop environment components

let
  llamaswapUrl = "http://${constants.network.ninho.vpnIp}:${toString constants.ports.llamaswap}";
  searxngUrl = "http://${constants.network.ninho.vpnIp}:${toString constants.ports.searxng}";

  # Wraps `claude` to route through ninho's llama-swap endpoint with a chosen model.
  #  - model:        used for Opus and Sonnet slots
  #  - haikuModel:   used for Haiku slot (defaults to `model`)
  #  - haikuEnvVar:  if set, lets that env var override haikuModel at run-time
  #  - disallowedTools: tools the endpoint cannot serve, removed from the session
  #  - mcpServers:   MCP servers added to the session (Claude Code's `mcpServers`
  #                  schema); their tools are allowed without a permission check
  #  - contextTokens: the model's real context window. Claude Code doesn't know
  #                  these model IDs, so without it it assumes 200K and compacts there.
  mkClaudeWrapper =
    {
      name,
      model,
      haikuModel ? model,
      haikuEnvVar ? null,
      disallowedTools ? [ ],
      mcpServers ? { },
      contextTokens ? null,
    }:
    let
      haikuExpr = if haikuEnvVar == null then haikuModel else "\${${haikuEnvVar}:-${haikuModel}}";
      # Must be the `=` form. Written as `--disallowedTools X "$@"` the option is
      # variadic and takes a positional prompt as more tool names.
      denyArgs = lib.optionalString (disallowedTools != [ ]) (
        lib.escapeShellArg "--disallowedTools=${lib.concatStringsSep "," disallowedTools}" + " "
      );
      # The `=` form again: both of these options are variadic as well.
      mcpArgs = lib.optionalString (mcpServers != { }) (
        lib.escapeShellArgs [
          "--mcp-config=${pkgs.writeText "${name}-mcp.json" (builtins.toJSON { inherit mcpServers; })}"
          "--allowedTools=${lib.concatMapStringsSep "," (s: "mcp__${s}") (lib.attrNames mcpServers)}"
        ]
        + " "
      );
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ ];
      text = ''
        export ANTHROPIC_BASE_URL="${llamaswapUrl}"
        export ANTHROPIC_API_KEY="not-needed"
        export API_TIMEOUT_MS="3000000"
        # llama-swap sends nothing until a cold model is up (Flash-Next on Strata
        # takes ~85 s), and the first-byte window otherwise comes from a remote
        # flag (180 s), which a cold load plus a long session's re-prefill can pass.
        export CLAUDE_STREAM_FIRST_BYTE_TIMEOUT_MS=600000
        export CLAUDE_CODE_MAX_OUTPUT_TOKENS=100000
        export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
        export ANTHROPIC_DEFAULT_OPUS_MODEL="${model}"
        export ANTHROPIC_DEFAULT_SONNET_MODEL="${model}"
        # Unset, the fable alias (a subagent's `model: fable`) resolves to Fable 5.2,
        # which the endpoint doesn't serve.
        export ANTHROPIC_DEFAULT_FABLE_MODEL="${model}"
        export ANTHROPIC_DEFAULT_HAIKU_MODEL="${haikuExpr}"
        ${lib.optionalString (contextTokens != null) ''
          export CLAUDE_CODE_MAX_CONTEXT_TOKENS=${toString contextTokens}
        ''}
        # Force the main model with --model (highest precedence). The DEFAULT_*
        # env vars only rebind the opus/sonnet/haiku aliases, so a full model ID
        # persisted via `/model` (e.g. claude-fable-5[1m]) would otherwise win and
        # break against the llama-swap endpoint that doesn't serve it.
        exec claude --model "${model}" ${denyArgs}${mcpArgs}"$@"
      '';
    };

  glaude = mkClaudeWrapper {
    name = "glaude";
    model = "GLM-5";
    haikuModel = "GLM-4.5-Air";
  };
  # WebSearch is answered by Anthropic's server-side search tool. A local server
  # only hands the nested "perform a web search" prompt to the model: the 27B
  # then generates until CLAUDE_CODE_MAX_OUTPUT_TOKENS (minutes per call, then
  # an output-token error) and Flash-Next on Strata returns no results.
  # web_url_read duplicates WebFetch, and under the server-wide allow rule it
  # would fetch pages with no permission check.
  localDisallowedTools = [
    "WebSearch"
    "mcp__searxng__web_url_read"
  ];

  # The search that does work there: SearXNG on ninho (services/searxng.nix)
  # through mcp-searxng.
  localMcpServers.searxng = {
    command = lib.getExe pkgs.unstable.mcp-searxng;
    env.SEARXNG_URL = searxngUrl;
  };

  # The n_ctx -fit gives the 27B with Frigate and Sunshine stopped (its /props on
  # ninho). With another GPU tenant holding VRAM, -fit loads a shorter context.
  olaude-qwen3-8-27B = mkClaudeWrapper {
    name = "olaude-qwen3-8-27B";
    model = "qwen3.8-27B-full";
    haikuEnvVar = "OLAUDE_HAIKU";
    disallowedTools = localDisallowedTools;
    mcpServers = localMcpServers;
    contextTokens = 262144;
  };
  # The 27B with its vision projector loaded, for sessions that read images.
  # Its own llama-swap entry, so the plain wrapper keeps the longer context.
  olaude-qwen3-8-27B-vision = mkClaudeWrapper {
    name = "olaude-qwen3-8-27B-vision";
    model = "qwen3.8-27B-full-vision";
    haikuEnvVar = "OLAUDE_HAIKU";
    disallowedTools = localDisallowedTools;
    mcpServers = localMcpServers;
  };
  olaude-qwen3-8-flash-next = mkClaudeWrapper {
    name = "olaude-qwen3-8-flash-next";
    model = "qwen3.8-flash-next-strata";
    haikuEnvVar = "OLAUDE_HAIKU";
    disallowedTools = localDisallowedTools;
    mcpServers = localMcpServers;
    contextTokens = 262144; # Strata's --max-context (services/llama-cpp.nix)
  };

  # Pi coding agent wrapper for Ninho local models
  pi-local = pkgs.writeShellApplication {
    name = "pi-local";
    runtimeInputs = [ ];
    text = ''
      exec pi --provider ninho --model "''${PI_LOCAL_MODEL:-qwen3.8-27B-full}" "$@"
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
    ../../profiles/development-lean.nix # Lean toolchain (excluded on laptops)
    ../../profiles/specialized.nix

    # Program configurations
    ../../programs/ai-cmd/default.nix
    ../../programs/agda/default.nix
    ../../programs/bash/default.nix
    ../../programs/cctop/default.nix
    ../../programs/emacs/default.nix
    ../../programs/git/default.nix
    ../../programs/mcp-nixos/default.nix
    ../../programs/neovim/default.nix
    ../../programs/syncthing/default.nix
    ../../programs/tmux/default.nix
    ../../programs/herdr/default.nix

    # User-level systemd services (excludable per-machine)
    ../../services/emanote-user.nix

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
    # username, homeDirectory, keyboard and EDITOR/VISUAL come from common/base.nix.
    stateVersion = "25.05";

    sessionPath = [
      "${config.userConfig.homeDirectory}/.local/bin"
      "${config.userConfig.homeDirectory}/.cabal/bin"
      "${config.userConfig.homeDirectory}/.cargo/bin"
    ];

    # All packages managed through profiles
    packages = [
      glaude
      olaude-qwen3-8-27B
      olaude-qwen3-8-27B-vision
      olaude-qwen3-8-flash-next
      pi-local
      pi-glm
    ];
  };

  programs.git.includes = [
    {
      condition = "gitdir:~/x1-g8-laptop/Desktop/Bolt/UMinho/Profissional/Well-Typed/Projects/";
      contents.user.email = "armando@well-typed.com";
    }
  ];

  # Additional programs (headless - no firefox, no autorandr)
  programs = {
    ssh = {
      enable = true;
      # 26.05 home-manager: matchBlocks is a deprecated alias for `settings`,
      # keyed by host pattern with upstream OpenSSH directive names.
      enableDefaultConfig = false;

      settings = {
        # Default settings for all hosts
        "*" = {
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        };

        "rpi" = {
          HostName = constants.network.rpi.lanIp;
          User = "bolt";
        };
        "ninho" = {
          HostName = constants.network.ninho.vpnIp;
          User = "bolt";
        };
      };
    };
  };

  # Emanote user service lives in ../../services/emanote-user.nix (importable
  # so machines without journal data can disable it via disabledModules).
  services.gpg-agent = {
    enable = true;
    enableBashIntegration = true;
    # Defaults only: bolt-with-de imports this file, and its wayland profile
    # sets pinentry-all and its own cache TTLs for the desktop.
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
    # A working day. Non-interactive shells get no GPG_TTY (programs/bash
    # returns early for them), so pinentry-curses has no terminal to prompt on
    # and signing from one depends on the cache being warm.
    defaultCacheTtl = lib.mkDefault 28800;
    maxCacheTtl = lib.mkDefault 28800;
  };
}
