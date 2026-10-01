{ config, ... }:

# Bash configuration with user-specific parameterization
# Common bash settings (prompt, git functions) are defined here
# User-specific aliases are pulled from config.userConfig.bash.extraAliases

{
  programs.bash = {
    enable = true;
    historyFileSize = 100000;
    historySize = 100000;
    initExtra = ''
      # If not running interactively, don't do anything
      [[ $- != *i* ]] && return

      export GPG_TTY=$(tty)

      fastfetch
      set -o vi
    '';

    # Common aliases shared across all users
    # User-specific aliases are merged from config.userConfig.bash.extraAliases
    shellAliases = {
      ls = "ls --color=always";
      ll = "ls -l";
      lla = "ls -la";
      docker = "sudo docker";
      sudo = "sudo ";

      # Backward compatibility aliases for replaced tools
      tree = "eza --tree";
      ncdu = "dust";
      neofetch = "fastfetch";
      find = "fd";
    }
    // (config.userConfig.bash.extraAliases or { });
  };
}
