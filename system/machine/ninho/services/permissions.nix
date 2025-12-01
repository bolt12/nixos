{ config, ... }:
{
  # ============================================================================
  # Centralized Permission Management
  # ============================================================================
  # This module manages all service permissions for shared data access.
  # All services can read/write to /storage/data and /storage/media through
  # the 'media' group and 'storage-users' group.
  # ============================================================================

  # Needed for some reason this isn't set
  users.users.prowlarr.isSystemUser = true;
  users.users.prowlarr.group = "prowlarr";
  users.groups.prowlarr = {};

  # Create the media group for shared media access
  users.groups.media = {};

  # Add all service users to appropriate groups
  users.users = {
    # Media server - needs access to media files and hardware acceleration
    jellyfin.extraGroups = [ "media" "storage-users" "render" "video" "immich" "nextcloud" ];

    # Servarr stack - needs access to media files for management
    prowlarr.extraGroups = [ "media" "storage-users" ];
    radarr.extraGroups   = [ "media" "storage-users" ];
    sonarr.extraGroups   = [ "media" "storage-users" ];
    lidarr.extraGroups   = [ "media" "storage-users" ];
    readarr.extraGroups  = [ "media" "storage-users" ];

    # Download clients - need access to media files for downloads
    deluge.extraGroups = [ "media" "storage-users" ];

    # Cloud services - need access to share photos/files with other services
    nextcloud.extraGroups = [ "media" "storage-users" ];
    immich.extraGroups = [ "media" "storage-users" "render" "video" ];
  };
}
