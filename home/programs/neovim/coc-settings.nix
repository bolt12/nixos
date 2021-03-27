{

  "diagnostic.virtualText" = true;
  "codeLens.enable" = true;
  # "coc.preferences.formatOnSaveFiletypes" = ["haskell"];
  "coc.preferences.snippets.enable" = true;

  "languageserver" = {
    "dhall" = {
      "command" = "dhall-lsp-server";
      "filetypes" = [ "dhall" ];
    };

    "haskell" = {
        "command" = "haskell-language-server-wrapper";
        "args" = ["--lsp"];
        "rootPatterns" = [
            "*.cabal"
            ".hie-bios"
            "BUILD.bazel"
            ".stack.yaml"
            "cabal.config"
            "cabal.project"
            "package.yaml"
            "hie.yaml"
        ];
        "filetypes" = [
            "hs"
            "lhs"
            "haskell"
            "lhaskell"
        ];
        "settings" = {
            "haskell" = {
                "hlintOn" = true;
                "maxNumberOfProblems" = 10;
                "formattingProvider" = "stylish-haskell";
                "completionSnippetsOn" = true;
            };
        };
        "initializationOptions" = {
            "haskell" = {
                "hlintOn" = true;
                "maxNumberOfProblems" = 10;
                "formattingProvider" = "stylish-haskell";
                "completionSnippetsOn" = true;
            };
        };
    };

    "nix" = {
      "command" = "rnix-lsp";
      "filetypes" = [ "nix" ];
    };
  };

  "yank.highlight.duration" = 700;
}
