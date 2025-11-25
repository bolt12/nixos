{ config, ... }:

# User-specific data for pollard
# Contains ZFS learning aliases and helpful shortcuts

{
  userConfig.bash.extraAliases = {
    # NixOS help shortcuts
    nix-help = "man configuration.nix";
    nix-search = "nix search nixpkgs";
    nix-info = "nix-shell -p nix-info --run nix-info";
    hm-help = "man home-configuration.nix";
  };
}
