# Development profile - Programming tools and development environment
# This profile contains tools for software development across multiple languages

{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  nix-ai-tools = inputs.nix-ai-tools.packages.${system};

  # TEMPORARY: drop once nixos-26.05 backports unstable's fix
  # (https://github.com/NixOS/nixpkgs/issues/584492). VS Code 1.122+ ships rg as
  # @vscode/ripgrep-universal/bin/<system>/rg, and 26.05's package still replaces
  # the old @vscode/ripgrep/bin/rg, so 1.144.0 fails in postPatch. Once the
  # package uses the new path this replacement matches nothing.
  vscode =
    if lib.versionAtLeast pkgs.vscode.version "1.122.0" then
      pkgs.vscode.overrideAttrs (old: {
        postPatch =
          builtins.replaceStrings
            [ "@vscode/ripgrep/bin/rg" ]
            [ "@vscode/ripgrep-universal/bin/linux-x64/rg" ]
            old.postPatch;
      })
    else
      pkgs.vscode;
in
{

  home.packages = with pkgs; [
    # Version control and project management
    gh # GitHub CLI
    git-absorb # Automatic fixup commits
    git-annex # Git for large files
    git-extras # Additional git commands
    jujutsu # Modern Git-compatible VCS

    # Code editors and IDEs
    vscode # Visual Studio Code

    # General development tools
    jq # JSON processor
    nodejs # JavaScript runtime
    python3 # Python programming language

    # AI tools
    nix-ai-tools.ccstatusline # Claude code statusline
    nix-ai-tools.claude-code # Claude code
    nix-ai-tools.opencode # Opencode
    nix-ai-tools.pi # Pi coding agent

    # System development tools
    patchelf # ELF patcher for binaries

    # Documentation and reference
    tldr # Concise man pages
    manix # Nix documentation search
    nix-doc # Nix documentation tool
    nix-tree # Nix dependency visualization

    # Build and packaging tools
    cachix # Nix binary cache
    home-manager # User environment management

    # Container and virtualization
    # Note: Docker is enabled at system level

    # Network and cloud tools
    awscli2 # AWS CLI
    noip # Dynamic DNS client

    # Haskell development environment - comprehensive toolchain
    cabal2nix # Convert cabal projects to nix
    cabal-install # Cabal package manager
    haskellPackages.eventlog2html # GHC eventlog visualization
    haskellPackages.fast-tags # Fast tag generation
    haskellPackages.fourmolu # Code formatter
    haskellPackages.ghc # Glasgow Haskell Compiler
    haskellPackages.ghcide # GHC IDE support
    haskellPackages.haskell-language-server # LSP implementation
    haskellPackages.hoogle # Documentation search
    stack # Stack package manager
    stylish-haskell # Code formatter

    # Bleeding-edge development tools from unstable channel
    pkgs.unstable.nixd # Nix language server for IDE integration
  ];
}
