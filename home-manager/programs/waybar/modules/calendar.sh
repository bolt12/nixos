#!/usr/bin/env bash

# Simple calendar popup using zenity (much faster than gnome-calendar)
# This provides a quick, lightweight calendar popup

if command -v zenity >/dev/null 2>&1; then
    # Use zenity calendar for quick popup
    zenity --calendar --title="Calendar" --text="Select a date:" 2>/dev/null
elif command -v yad >/dev/null 2>&1; then
    # Alternative with yad if available
    yad --calendar --title="Calendar" --text="Select a date:" 2>/dev/null
elif command -v gtk-calendar >/dev/null 2>&1; then
    # Simple gtk calendar
    gtk-calendar
else
    # Fallback to terminal calendar
    if command -v cal >/dev/null 2>&1; then
        terminal_app="${TERMINAL:-konsole}"
        $terminal_app -e bash -c "cal; read -p 'Press Enter to close...'"
    else
        notify-send "Calendar" "No calendar application available"
    fi
fi
