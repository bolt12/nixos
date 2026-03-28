#!/bin/sh

# Display setup for X1 Carbon Gen 8 with USB-C dock
# The dock can't modeset both external monitors atomically —
# the LG 4K needs bandwidth freed by disabling other outputs first.

ULTRAWIDE="OOO BW-GM3 0000000000001"
LG4K="LG Electronics LG HDR 4K 0x000694F9"
LAPTOP="eDP-1"

wait_for_transform() {
    target_output="$1"
    target_transform="$2"
    for i in 1 2 3 4 5 6 7 8 9 10; do
        current=$(swaymsg -t get_outputs -r | jq -r ".[] | select(.name == \"$target_output\") | .transform")
        [ "$current" = "$target_transform" ] && return 0
        sleep 0.5
    done
    return 1
}

wait_for_mode() {
    target_output="$1"
    target_width="$2"
    for i in 1 2 3 4 5 6 7 8 9 10; do
        current=$(swaymsg -t get_outputs -r | jq -r ".[] | select(.name == \"$target_output\") | .current_mode.width")
        [ "$current" = "$target_width" ] && return 0
        sleep 0.5
    done
    return 1
}

sleep 2

# Find output names by make/model
UW_NAME=$(swaymsg -t get_outputs -r | jq -r '.[] | select(.make == "OOO" and .model == "BW-GM3") | .name')
LG_NAME=$(swaymsg -t get_outputs -r | jq -r '.[] | select(.make == "LG Electronics" and .model == "LG HDR 4K") | .name')

if [ -n "$UW_NAME" ] && [ -n "$LG_NAME" ]; then
    # Dual external: free bandwidth for LG first
    swaymsg output "$LAPTOP" disable
    swaymsg "output '$ULTRAWIDE' disable"
    sleep 2

    # Set LG 4K portrait while it has full bandwidth
    swaymsg "output '$LG4K' enable mode 3840x2160@30Hz transform 270 scale 2"
    wait_for_transform "$LG_NAME" "270"
    sleep 1

    # Re-enable ultrawide
    swaymsg "output '$ULTRAWIDE' enable mode 3440x1440@60Hz position 0 0"
    wait_for_mode "$UW_NAME" "3440"
    sleep 1

    # Position LG to the right of ultrawide
    swaymsg "output '$LG4K' position 3440 0"

elif [ -n "$UW_NAME" ]; then
    swaymsg output "$LAPTOP" disable
    swaymsg "output '$ULTRAWIDE' mode 3440x1440@60Hz position 0 0"

elif [ -n "$LG_NAME" ]; then
    swaymsg output "$LAPTOP" disable
    swaymsg "output '$LG4K' mode 3840x2160@30Hz transform 270 scale 2"
fi
