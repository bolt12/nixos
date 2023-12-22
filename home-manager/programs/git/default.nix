{ ... }:

let
  gitConfig = {
    core = {
      editor = "nvim";
    };
    merge.tool = "vimdiff";
    mergetool = {
      cmd    = "nvim -f -c \"Gvdiffsplit!\" \"$MERGED\"";
      prompt = false;
    };
    pull.rebase = false;
  };
in
{
  programs.git = {
    enable = true;
    aliases = { };
    extraConfig = gitConfig;
    ignores = [
      "*.direnv"
      "*.envrc" # there is lorri, nix-direnv & simple direnv; let people decide
      "*hie.yaml" # ghcide files
    ];
    userEmail = "armandoifsantos@gmail.com";
    userName = "Armando Santos";

    signing.key = null;
    signing.signByDefault = true;

    delta = {
      enable = true;
      options = {
        side-by-side = true;
        line-numbers = true;
        hyperlinks = true;
        true-color = "always";
      };
    };
  };
}
