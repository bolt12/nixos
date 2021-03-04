{
  programs.bash = {
      enable = true;
      historyFileSize = 100000;
      historySize = 100000;
      initExtra = ''
        # If not running interactively, don't do anything
        [[ $- != *i* ]] && return

        neofetch
        '';
      shellAliases = {
        ls = "ls --color=always";
        ll = "ls -l";
        lla = "ls -la";
        uminho = "cd /home/bolt/Desktop/Bolt/UMinho/";
        tese = "cd /home/bolt/Desktop/Bolt/UMinho/5ºAno/Tese";
        haskell = "cd /home/bolt/Desktop/Bolt/Playground/Haskell/";
        talks = "cd /home/bolt/Desktop/Bolt/Playground/Talks/";
        agda = "cd /home/bolt/Desktop/Bolt/Playground/Agda/";
        playg = "cd /home/bolt/Desktop/Bolt/Playground/";
        sicstus = "rlwrap sicstus";
        idris2 = "rlwrap idris2";
        docker ="sudo docker";
        sudo = "sudo ";
        doom = "/home/bolt/.emacs.d/bin/doom";
        welltyped = "cd /home/bolt/Desktop/Bolt/UMinho/Profissional/Well-Typed/";
      };
    };
}
