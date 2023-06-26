{

  "diagnostic.virtualText" = true;
  "codeLens.enable" = true;
  # "coc.preferences.formatOnSaveFiletypes" = ["haskell"];
  "coc.preferences.snippets.enable" = true;

  # Important, otherwise link completion containing spaces and other special characters won't work.
  "suggest.invalidInsertCharacters" = [];

  "languageserver" = {
    "dhall" = {
      "command" = "dhall-lsp-server";
      "filetypes" = [ "dhall" ];
    };

    "haskell" = {
        "command" = "haskell-language-server";
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

    "zk" = {
      "command" = "zk";
      "args" = ["lsp"];
      "trace.server" = "messages";
      "filetypes" = ["markdown"];
    };
  };

  "yank.highlight.duration" = 700;
}
