{ pkgs, ... }:

let
  mod = "Mod1";
  lockCmd = "swaylock --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5 --grace 5 --fade-in 0.2";
  wallpaper = ../../background.png;
in
{
  services.gnome-keyring.enable = true;

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures = {
      base = true;
      gtk = true;
    };
    xwayland = true;

    extraSessionCommands = ''
      export _JAVA_AWT_WM_NONREPARENTING=1
      export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true"
      export SUDO_ASKPASS="${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
      export SSH_ASKPASS="${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
    '';

    config = {
      modifier = mod;
      terminal = "konsole";
      menu = "fuzzel";

      fonts = {
        names = [ "JetBrains Mono" ];
        size = 9.0;
      };

      floating = {
        modifier = mod;
        border = 2;
      };

      focus.followMouse = true;

      window = {
        border = 1;
        hideEdgeBorders = "smart";
        commands = [
          # Inhibit idle for fullscreen media
          {
            command = "inhibit_idle fullscreen";
            criteria = {
              app_id = "firefox";
            };
          }
          {
            command = "inhibit_idle fullscreen";
            criteria = {
              app_id = "mpv";
            };
          }
          {
            command = "inhibit_idle fullscreen";
            criteria = {
              class = "Chromium";
            };
          }
          {
            command = "inhibit_idle fullscreen";
            criteria = {
              class = "Google-chrome";
            };
          }
          {
            command = "inhibit_idle visible";
            criteria = {
              app_id = "org.videolan.VLC";
            };
          }

          # Auto-float dialogs and utility windows
          {
            command = "floating enable";
            criteria = {
              window_role = "pop-up";
            };
          }
          {
            command = "floating enable";
            criteria = {
              window_role = "bubble";
            };
          }
          {
            command = "floating enable";
            criteria = {
              window_type = "dialog";
            };
          }
          {
            command = "floating enable, resize set 800 600, move position center";
            criteria = {
              title = "(?:Open|Save) (?:File|Folder|As)";
            };
          }
          {
            command = "floating enable, resize set 800 600, move position center";
            criteria = {
              app_id = "pwvucontrol";
            };
          }
          {
            command = "floating enable, resize set 600 400, move position center";
            criteria = {
              app_id = "blueman-manager";
            };
          }
          {
            command = "floating enable";
            criteria = {
              app_id = "nm-connection-editor";
            };
          }
        ];
      };

      gaps = {
        inner = 8;
        outer = 4;
        smartBorders = "on";
        smartGaps = false;
      };

      colors = {
        focused = {
          border = "#89b4fa";
          background = "#313244";
          text = "#cdd6f4";
          indicator = "#89b4fa";
          childBorder = "#89b4fa";
        };
        focusedInactive = {
          border = "#6c7086";
          background = "#45475a";
          text = "#cdd6f4";
          indicator = "#6c7086";
          childBorder = "#6c7086";
        };
        unfocused = {
          border = "#45475a";
          background = "#1e1e2e";
          text = "#6c7086";
          indicator = "#45475a";
          childBorder = "#45475a";
        };
        urgent = {
          border = "#f38ba8";
          background = "#1e1e2e";
          text = "#cdd6f4";
          indicator = "#f38ba8";
          childBorder = "#f38ba8";
        };
        placeholder = {
          border = "#1e1e2e";
          background = "#11111b";
          text = "#cdd6f4";
          indicator = "#1e1e2e";
          childBorder = "#1e1e2e";
        };
        background = "#1e1e2e";
      };

      input = {
        "type:keyboard" = {
          xkb_layout = "us";
          xkb_options = "caps:escape";
        };
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          dwt = "enabled";
          accel_profile = "adaptive";
          click_method = "clickfinger";
        };
      };

      # Display config managed by kanshi (services.kanshi in home.nix)
      # Only wallpaper is set here
      output = {
        "*" = {
          bg = "${wallpaper} fill";
        };
      };

      keybindings = {
        # Terminal
        "${mod}+Return" = "exec konsole";

        # Kill focused window
        "${mod}+Shift+q" = "kill";

        # Focus (vim-style)
        "${mod}+j" = "focus left";
        "${mod}+k" = "focus down";
        "${mod}+l" = "focus up";
        "${mod}+semicolon" = "focus right";

        # Focus (arrow keys)
        "${mod}+Left" = "focus left";
        "${mod}+Down" = "focus down";
        "${mod}+Up" = "focus up";
        "${mod}+Right" = "focus right";

        # Move window (vim-style)
        "${mod}+Shift+j" = "move left";
        "${mod}+Shift+k" = "move down";
        "${mod}+Shift+l" = "move up";
        "${mod}+Shift+semicolon" = "move right";

        # Move window (arrow keys)
        "${mod}+Shift+Left" = "move left";
        "${mod}+Shift+Down" = "move down";
        "${mod}+Shift+Up" = "move up";
        "${mod}+Shift+Right" = "move right";

        # Split / layout
        "${mod}+t" = "split toggle";
        "${mod}+f" = "fullscreen toggle";
        "${mod}+s" = "layout stacking";
        "${mod}+w" = "layout tabbed";
        "${mod}+e" = "layout toggle split";

        # Floating
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+space" = "focus mode_toggle";

        # Focus parent/child
        "${mod}+a" = "focus parent";
        "${mod}+z" = "focus child";

        # Workspaces
        "${mod}+1" = "workspace number 1";
        "${mod}+2" = "workspace number 2";
        "${mod}+3" = "workspace number 3";
        "${mod}+4" = "workspace number 4";
        "${mod}+5" = "workspace number 5";
        "${mod}+6" = "workspace number 6";
        "${mod}+7" = "workspace number 7";
        "${mod}+8" = "workspace number 8";
        "${mod}+9" = "workspace number 9";
        "${mod}+0" = "workspace number 10";

        # Move container to workspace
        "${mod}+Shift+1" = "move container to workspace number 1";
        "${mod}+Shift+2" = "move container to workspace number 2";
        "${mod}+Shift+3" = "move container to workspace number 3";
        "${mod}+Shift+4" = "move container to workspace number 4";
        "${mod}+Shift+5" = "move container to workspace number 5";
        "${mod}+Shift+6" = "move container to workspace number 6";
        "${mod}+Shift+7" = "move container to workspace number 7";
        "${mod}+Shift+8" = "move container to workspace number 8";
        "${mod}+Shift+9" = "move container to workspace number 9";
        "${mod}+Shift+0" = "move container to workspace number 10";

        # Scratchpad
        "${mod}+Shift+minus" = "move scratchpad";
        "${mod}+Shift+equal" = "scratchpad show";

        # Session
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+r" = "restart";
        "${mod}+Shift+e" = "exec wlogout";

        # Resize mode
        "${mod}+r" = "mode resize";

        # App launcher
        "${mod}+d" = "exec fuzzel";

        # Flash current window
        "${mod}+n" = "exec flash_window";

        # Lock screen (swaylock-effects with blur + clock)
        "${mod}+Shift+x" = "exec ${lockCmd}";

        # Volume (wpctl — PipeWire native)
        "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

        # Brightness
        "XF86MonBrightnessDown" = "exec brightnessctl set 10%-";
        "XF86MonBrightnessUp" = "exec brightnessctl set +10%";

        # Clipboard history
        "${mod}+v" = "exec cliphist list | fuzzel --dmenu | cliphist decode | wl-copy";

        # Screenshots
        "${mod}+alt+p" = "exec grim - | wl-copy";
        "${mod}+Shift+p" = ''exec grim -g "$(slurp)" - | wl-copy'';
        "${mod}+Control+Shift+p" =
          "exec grim -o $(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name') - | wl-copy";

        # Screenshot annotation (satty)
        "${mod}+Shift+s" = ''exec grim -g "$(slurp)" - | satty -f -'';

        # OCR — capture region, extract text to clipboard
        "${mod}+Shift+o" = ''exec grim -g "$(slurp)" - | tesseract stdin stdout | wl-copy'';

        # Window switcher (swayr)
        "${mod}+Tab" = "exec swayr switch-window";

        # Border styles
        "${mod}+y" = "border none";
        "${mod}+u" = "border pixel 1";
        "${mod}+i" = "border normal";

        # Toggle LG monitor (for when it's cabled but powered off —
        # kanshi can't tell, so manually disable to trigger BlitzWolf-only profile)
        "${mod}+Shift+m" = ''exec swaymsg -t get_outputs | jq -r '.[] | select(.name | test("DP-[0-9]+")) | select(.make == "LG Electronics") | .name' | xargs -I{} swaymsg output "{}" toggle'';
      };

      modes = {
        resize = {
          "j" = "resize shrink width 10 px or 10 ppt";
          "k" = "resize grow height 10 px or 10 ppt";
          "l" = "resize shrink height 10 px or 10 ppt";
          "semicolon" = "resize grow width 10 px or 10 ppt";
          "Left" = "resize shrink width 10 px or 10 ppt";
          "Down" = "resize grow height 10 px or 10 ppt";
          "Up" = "resize shrink height 10 px or 10 ppt";
          "Right" = "resize grow width 10 px or 10 ppt";
          "Return" = "mode default";
          "Escape" = "mode default";
          "${mod}+r" = "mode default";
        };
      };

      bars = [
        { command = "waybar"; }
      ];

      startup = [
        # Environment setup for portals and systemd
        { command = "systemctl --user import-environment"; }
        {
          command = "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway";
        }

        # PipeWire audio stack
        {
          command = "systemctl --user restart pipewire pipewire-pulse.service pipewire-pulse.socket pipewire.socket wireplumber.service";
        }

        # System tray applets
        {
          command = "nm-applet --indicator";
          always = true;
        }
        {
          command = "blueman-applet";
          always = true;
        }

        # Input method
        { command = "fcitx5"; }

        # PipeWire session manager
        { command = "wireplumber"; }

        # Autotiling — auto-alternate horizontal/vertical splits
        {
          command = "autotiling";
          always = true;
        }

        # Clipboard history daemon
        { command = "wl-paste --type text --watch cliphist store"; }
        { command = "wl-paste --type image --watch cliphist store"; }

        # Notification center
        { command = "swaync"; }

        # Window switcher daemon
        { command = "env RUST_BACKTRACE=1 swayrd"; }

        # Laptop lid initial state check
        {
          command = "~/.config/sway/laptop-lid.sh";
          always = true;
        }

        # GTK theme/icons/cursor managed by Stylix (home.nix)
        # Only set font and GTK4/libadwaita dark mode via gsettings
        {
          command = "gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11'";
          always = true;
        }
        {
          command = "gsettings set org.gnome.desktop.interface color-scheme prefer-dark";
          always = true;
        }
      ];
    };

    extraConfig = ''
      # Performance tuning
      output * max_render_time 6

      # Workspace output assignments (with fallback monitors)
      workspace 1 output "OOO BW-GM3 0000000000001" eDP-1
      workspace 2 output "OOO BW-GM3 0000000000001" eDP-1
      workspace 3 output "LG Electronics LG HDR 4K 0x000694F9" eDP-1

      # Default focus on ultrawide
      focus output "OOO BW-GM3 0000000000001"

      # Laptop lid switch
      set $laptop eDP-1
      bindswitch --reload --locked lid:on output $laptop disable
      bindswitch --reload --locked lid:off output $laptop enable
    '';
  };

  # Laptop lid handler script
  xdg.configFile."sway/laptop-lid.sh" = {
    source = ../../xdg/sway/laptop-lid.sh;
    executable = true;
  };

}
