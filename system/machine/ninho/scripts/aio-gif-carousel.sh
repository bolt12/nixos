#!/usr/bin/env bash

# AIO LCD GIF Carousel Script
#
# Cycles through GIFs in a directory and displays them on the AIO cooler LCD
# Each GIF is displayed for 6 seconds with 180-degree rotation

set -euo pipefail

# Configuration
GIF_DIR="/home/bolt/x1-g8-laptop/Desktop/FanLCDGIFs"
DISPLAY_TIME=6
ORIENTATION=180

# Validate directory
if [ ! -d "$GIF_DIR" ]; then
    echo "Error: GIF directory '$GIF_DIR' does not exist"
    exit 1
fi

# Initialize liquidctl (detect and initialize devices)
echo "Initializing liquidctl devices..."
liquidctl initialize all

# Main carousel loop
echo "Starting GIF carousel from $GIF_DIR"
echo "Display time: ${DISPLAY_TIME}s | Orientation: ${ORIENTATION}°"

while true; do
    # Find all GIF files
    shopt -s nullglob
    gifs=("$GIF_DIR"/*.gif)
    shopt -u nullglob

    if [ ${#gifs[@]} -eq 0 ]; then
        echo "No GIF files found in $GIF_DIR. Waiting..."
        sleep 30
        continue
    fi

    echo "Found ${#gifs[@]} GIF(s)"

    # Loop through each GIF
    for gif in "${gifs[@]}"; do
        filename=$(basename "$gif")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Displaying: $filename"

        # Display GIF on LCD with orientation
        liquidctl set lcd screen gif $gif || {
            echo "Warning: Failed to display $filename"
        }
        liquidctl set lcd screen orientation $ORIENTATION

        # Wait before showing next GIF
        sleep "$DISPLAY_TIME"
    done
done
