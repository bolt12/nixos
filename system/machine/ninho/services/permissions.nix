# Centralized group/permission management: wires service users into media + storage-users.
{ lib, ... }:
let
  # Services that create files under /storage/media. Each one has to be able
  # to change what another created (Jellyfin and Bazarr save subtitles next to
  # an episode Sonarr imported), so they all run with a group-writable umask.
  # deluged is not listed: its module already sets 0002.
  libraryWriters = [
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
    "bazarr"
    "jellyfin"
  ];
in
{
  # ============================================================================
  # Centralized Permission Management
  # ============================================================================
  # This module manages all service permissions for shared data access.
  # 'media' is the write group for the library and the downloads
  # (/storage/media/*, /storage/torrents); the SGID roots in servarr.nix put
  # new files in it. 'storage-users' owns the /storage roots themselves.
  # ============================================================================

  # mkForce because the sonarr, radarr and jellyfin modules set a UMask of
  # their own (0022, 0022, 0077).
  systemd.services = lib.genAttrs libraryWriters (_: {
    serviceConfig.UMask = lib.mkForce "0002";
  });

  # Needed for some reason this isn't set
  users.users.prowlarr.isSystemUser = true;
  users.users.prowlarr.group = "prowlarr";
  users.groups.prowlarr = { };

  # Create the media group for shared media access
  users.groups.media = { };

  # Add all service users to appropriate groups
  users.users = {
    # Media server - needs access to media files and hardware acceleration
    jellyfin.extraGroups = [
      "media"
      "storage-users"
      "render"
      "video"
      "immich"
      "nextcloud"
    ];

    # Servarr stack - needs access to media files for management
    radarr.extraGroups = [
      "media"
      "storage-users"
    ];
    sonarr.extraGroups = [
      "media"
      "storage-users"
    ];
    lidarr.extraGroups = [
      "media"
      "storage-users"
    ];
    readarr.extraGroups = [
      "media"
      "storage-users"
    ];

    # Download clients - need access to media files for downloads
    deluge.extraGroups = [
      "media"
      "storage-users"
    ];

    # Cloud services - need access to share photos/files with other services.
    # Not in 'media': neither of them manages the library.
    nextcloud.extraGroups = [
      "storage-users"
    ];
    immich.extraGroups = [
      "storage-users"
      "render"
      "video"
    ];

    # Subtitle manager - needs media access
    bazarr.extraGroups = [
      "media"
      "storage-users"
    ];
  };
}
