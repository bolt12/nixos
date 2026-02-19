{ pkgs, ... }:
let
  ai-cmd = pkgs.writers.writeHaskellBin "ai"
    {
      libraries = with pkgs.haskellPackages; [
        aeson
        http-client
        http-client-tls
        optparse-applicative
        haskeline
        vector
      ];
    }
    (builtins.readFile ./Main.hs);
in
{
  home.packages = [ ai-cmd ];
}
