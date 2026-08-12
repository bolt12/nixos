# Emanote journal server (user-level systemd service).
# Bolt-specific personal journal, pulled in only on machines where bolt's
# journal layers actually live. Currently: ninho (headless bolt).

{
  inputs,
  system,
  constants,
  config,
  ...
}:

{
  systemd.user.services.emanote = {
    Unit = {
      Description = "Emanote journal server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${
        inputs.emanote.packages.${system}.default
      }/bin/emanote --layers \"%h/journal\" run --no-ws --host=0.0.0.0 --port=${toString constants.ports.emanote}";
      Restart = "always";
      RestartSec = "10";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
