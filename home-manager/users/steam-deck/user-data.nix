{ config, ... }:

# User-specific data for Steam Deck

{
  userConfig.bash.extraAliases = {
    # Steam Deck specific shortcuts
    games = "cd ${config.userConfig.homeDirectory}/.steam/steam/steamapps/common";
    desktop-mode = "qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout";
  };
}
