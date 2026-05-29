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
      default = { };
      description = "User-specific bash aliases";
      example = {
        projects = "cd ~/projects";
        work = "cd ~/work";
      };
    };

    sway = {
      primaryMonitor = mkOption {
        type = types.str;
        default = "eDP-1";
        description = "Primary Sway output name";
        example = "eDP-1";
      };

      externalMonitor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "External monitor output name (null = laptop only)";
        example = "OOO BW-GM3 0000000000001";
      };

      wallpaperPath = mkOption {
        type = types.path;
        # Resolved relative to home-manager/common/ → home-manager/wallpapers/...
        default = ../wallpapers/earth-moon-bg.jpg;
        description = "Sway desktop wallpaper image";
      };
    };

    niri = {
      primaryMonitor = mkOption {
        type = types.str;
        default = "eDP-1";
        description = "Primary niri output name (laptop panel).";
        example = "eDP-1";
      };

      externalMonitor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Primary external monitor identifier. Niri matches by connector
          name (e.g. "DP-1") or "Manufacturer Model Serial". Set to null
          when no external is configured.
        '';
        example = "OOO BW-GM3 0000000000001";
      };

      portraitMonitor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional portrait-rotated monitor identifier.";
        example = "LG Electronics LG HDR 4K 0x000694F9";
      };

      wallpaperPath = mkOption {
        type = types.path;
        default = ../wallpapers/earth-moon-bg.jpg;
        description = "Niri desktop wallpaper (consumed by swaybg).";
      };

      portraitWallpaperPath = mkOption {
        type = types.path;
        default = ../wallpapers/earth-moon-bg.jpg;
        description = ''
          Wallpaper for the portrait-rotated output. Pinned via a second
          swaybg instance with -m fit so a landscape source letterboxes
          instead of cropping.
        '';
      };
    };

    agda = {
      libraryRoot = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Root path containing standard-library, agda-categories, agda-prelude.
          Set to null to skip Agda library wiring entirely.
        '';
        example = "/home/bolt/Desktop/Bolt/Playground/Agda";
      };
    };
  };
}
