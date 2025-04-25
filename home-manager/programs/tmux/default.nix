{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
    mouse = true;
    shortcut = "a";
    extraConfig = ''
        set -g default-terminal "screen-256color"
        # Resize panes using Prefix + Ctrl + hjkl (repeatable)
        bind -r C-h resize-pane -L 5
        bind -r C-j resize-pane -D 5
        bind -r C-k resize-pane -U 5
        bind -r C-l resize-pane -R 5

        bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
        bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel # copy text with "y"
        bind-key -T copy-mode-vi 'Y' send-keys -X copy-line
        bind-key -T copy-mode-vi Escape send-keys -X cancel

        unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode after dragging with mouse

        # Reduce escape time for faster responsiveness (esp. with Vim)
        set -sg escape-time 10 # Or 0

        # Split panes using | and - (Vim-like) in current path
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        unbind '"' # Unbind default horizontal split
        unbind %   # Unbind default vertical split

        # Switch panes using Prefix + hjkl (Vim-like navigation)
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R
      '';
    plugins = [
      { plugin = pkgs.tmuxPlugins.resurrect;
        extraConfig = ''
          # allow tmux-ressurect to capture pane contents
          set -g @resurrect-capture-pane-contents 'on'
          '';
      }
      { plugin = pkgs.tmuxPlugins.continuum;
      extraConfig = ''
          # enable tmux-continuum functionality
          set -g @continuum-restore 'on'
          '';
      }
      { plugin = pkgs.tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_window_status_style "rounded"
          # Make the status line pretty and add some modules
          set -g status-right-length 100
          set -g status-left-length 100
          set -g status-left ""
          set -g status-right "#{E:@catppuccin_status_application}"
          set -agF status-right "#{E:@catppuccin_status_cpu}"
          set -ag status-right "#{E:@catppuccin_status_session}"
          set -ag status-right "#{E:@catppuccin_status_uptime}"
          set -agF status-right "#{E:@catppuccin_status_battery}"

          set -g @catppuccin-tmux_show_git 0
          set -g @catppuccin-tmux_pane_id_style hide
          set -g @catppuccin-tmux_zoom_id_style hide
          set -g @catppuccin-tmux_show_path 1
          '';
      }
    ];
  };
}
