# User declarations — bolt (admin) and pollard.
# Initial passwords are placeholders; change after first deploy.
{ ... }:
{
  users = {
    groups = {
      storage-users = { };
    };

    users = {
      bolt = {
        isNormalUser = true;
        description = "Armando";
        extraGroups = [
          "wheel" # sudo access
          "networkmanager"
          "docker"
          "audio"
          "video"
          "sway"
          "plugdev"
          "storage-users"
          "media"
        ];
        initialPassword = "ninho"; # CHANGE AFTER FIRST LOGIN
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKTf4Bb2BBymwZvxPtxEefspOPTACPn3HqrRiWAMJEJ armandoifsantos@gmail.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYYbDnCMLVnqStnWbX6nkYXLCMtbXnK7YWifGhHIA5m u0_a378@localhost" # Pixel 10 (Termux)
        ];
      };

      pollard = {
        isNormalUser = true;
        linger = true; # Keep user services running after logout
        description = "Claudia";
        extraGroups = [
          "wheel" # sudo access
          "networkmanager"
          "docker"
          "audio"
          "video"
          "sway"
          "plugdev"
          "storage-users"
          "media"
        ];
        initialPassword = "ninho"; # CHANGE AFTER FIRST LOGIN

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBqERTS3WbTIgNxGLVMNMNoI5qN277fDAkGeAboztJU claudiacorreiaa7@gmail.com"
        ];
      };
    };
  };
}
