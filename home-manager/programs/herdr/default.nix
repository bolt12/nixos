{ inputs, system, ... }:
{
  # herdr: tmux-like, agent-aware terminal multiplexer (single Rust binary).
  # Not in nixpkgs; consumed from the upstream flake input. See flake.nix.
  home.packages = [ inputs.herdr.packages.${system}.default ];

  # herdr reads TOML from ~/.config/herdr/config.toml.
  #
  # Only the prefix is overridden. herdr's defaults already track the tmux/vi
  # conventions used in programs/tmux/default.nix: pane nav (prefix h/j/k/l),
  # down-split (prefix -), vi copy-mode (v select / y yank), zoom (prefix z).
  # The sole real divergence worth fixing up front is the leader key, since
  # herdr defaults to ctrl+b while tmux here uses ctrl+a.
  #
  # Reload after edits without restarting: `herdr server reload-config`.
  xdg.configFile."herdr/config.toml".text = ''
    [keys]
    prefix = "ctrl+a"
  '';
}
