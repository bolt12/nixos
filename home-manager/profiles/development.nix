# Development profile - Programming tools and development environment
# This profile contains tools for software development across multiple languages

{ inputs, pkgs, ... }: 
let
  # Import unstable packages for bleeding-edge development tools
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    overlays = [];
  };
in {
  home.packages = with pkgs; [
    # Version control and project management
    gh                           # GitHub CLI
    git-absorb                   # Automatic fixup commits
    git-annex                    # Git for large files
    git-extras                   # Additional git commands
    jujutsu                      # Modern Git-compatible VCS

    # Code editors and IDEs
    vscode                       # Visual Studio Code

    # General development tools
    jq                           # JSON processor
    nodejs                       # JavaScript runtime
    python3                      # Python programming language
    
    # System development tools
    patchelf                     # ELF patcher for binaries
    
    # Documentation and reference
    tldr                         # Concise man pages
    manix                        # Nix documentation search
    nix-doc                      # Nix documentation tool
    nix-index                    # Nix package search
    nix-tree                     # Nix dependency visualization
    
    # Build and packaging tools
    cachix                       # Nix binary cache
    home-manager                 # User environment management
    nixops                       # NixOS deployment tool
    
    # Container and virtualization
    # Note: Docker is enabled at system level
    
    # Network and cloud tools
    awscli2                      # AWS CLI
    wireguard-tools              # VPN tools
    noip                         # Dynamic DNS client
    
    # Haskell development environment - comprehensive toolchain
    cabal2nix                                 # Convert cabal projects to nix
    cabal-install                             # Cabal package manager
    haskellPackages.eventlog2html             # GHC eventlog visualization
    haskellPackages.fast-tags                 # Fast tag generation
    haskellPackages.fourmolu                  # Code formatter
    haskellPackages.ghc                       # Glasgow Haskell Compiler
    haskellPackages.ghcide                    # GHC IDE support
    haskellPackages.haskell-language-server   # LSP implementation
    haskellPackages.hoogle                    # Documentation search
    stack                                     # Stack package manager
    stylish-haskell                           # Code formatter
  ] ++ [
    # Bleeding-edge development tools from unstable channel
    unstable.nixd                             # Nix language server for IDE integration
  ];
}