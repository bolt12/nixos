{ ... }:

let
  gitConfig = {
    core = {
      editor = "nvim";
      whitespace = "trailing-space,space-before-tab,tab-in-indent";

      # Optional: show whitespace errors
      diff.wsErrorHighlight = "all";
    };
    apply = {
      whitespace = "fix";
    };
    diff = {
      wsErrorHighlight = "all";
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
    aliases = {
      # Short forms for common commands - improves daily workflow efficiency
      st = "status -s";              # Concise status overview
      co = "checkout";               # Switch branches/restore files
      br = "branch";                 # Branch management
      ci = "commit";                 # Create commits

      # Advanced productivity shortcuts
      unstage = "reset HEAD --";            # Remove files from staging area
      last    = "log -1 HEAD";              # Show last commit details
      visual  = "!gitk";                    # Launch visual git history viewer
      amend   = "commit --amend --no-edit"; # Amend last commit without changing message

      # Interactive fixup workflow - requires fzf for fuzzy commit selection
      fixup = "!git log --oneline -n 50 | fzf | cut -d' ' -f1 | xargs -r git commit --fixup";
    };
    extraConfig = gitConfig;
    ignores = [
      "*.direnv"
      "*.envrc" # there is lorri, nix-direnv & simple direnv; let people decide
      "*hie.yaml" # ghcide files
      "*.vim"
      "tags"
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
