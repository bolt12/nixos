{
  nix = {
    binaryCaches          =
      [ "https://hydra.iohk.io"
        "https://iohk.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
      ];
    binaryCachePublicKeys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      ];
  };
}
