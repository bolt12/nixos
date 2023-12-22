{
  programs.ssh.extraConfig = ''
    Host dev-deployer
        Hostname 3.124.147.122
        User dev
        IdentityFile /home/bolt/.ssh/id_ed25519
  '';
}
