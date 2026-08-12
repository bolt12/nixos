# Agda library wiring, generates ~/.agda/{libraries,defaults,executables}
# from `userConfig.agda.libraryRoot`. Set the option in your user-data.nix
# (e.g. `userConfig.agda.libraryRoot = "${config.userConfig.homeDirectory}/Desktop/.../Agda";`)
# or leave it null to skip wiring entirely.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  root = config.userConfig.agda.libraryRoot;
  enabled = root != null;
in
{
  home.file.".agda/libraries" = lib.mkIf enabled {
    text = ''
      ${root}/agda-stdlib/standard-library.agda-lib
      ${root}/agda-categories/agda-categories.agda-lib
      ${root}/agda-prelude/agda-prelude.agda-lib
    '';
  };

  home.file.".agda/defaults" = lib.mkIf enabled {
    text = ''
      standard-library-2.3
      agda-categories
      agda-prelude
    '';
  };

  # Agda's `executables` file is a single line pointing at a fallback shell
  # tool. Generated through Nix so the path is stable across machines.
  home.file.".agda/executables" = lib.mkIf enabled {
    text = "${pkgs.coreutils}/bin/cat\n";
  };
}
