{ lib, ... }:

# Options module for user-specific configuration
# This provides a typed interface for parameterizing user-specific values
# across all home-manager configurations

with lib;
{
  options.userConfig = {
    username = mkOption {
      type = types.str;
      description = "The user's username";
      example = "bolt";
    };

    homeDirectory = mkOption {
      type = types.str;
      description = "The user's home directory path";
      example = "/home/bolt";
    };

    git = {
      userName = mkOption {
        type = types.str;
        description = "Git user name for commits";
        example = "Armando Santos";
      };

      userEmail = mkOption {
        type = types.str;
        description = "Git user email for commits";
        example = "user@example.com";
      };

      signingKey = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "GPG key ID for signing commits (null for default key)";
        example = "0x1234567890ABCDEF";
      };
    };

    bash.extraAliases = mkOption {
      type = types.attrs;
      default = {};
      description = "User-specific bash aliases";
      example = {
        projects = "cd ~/projects";
        work = "cd ~/work";
      };
    };
  };
}
