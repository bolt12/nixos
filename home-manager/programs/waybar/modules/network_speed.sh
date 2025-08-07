#!/bin/bash

# Get network interface (you might need to change 'eth0' or 'wlan0' to your actual interface)
# You can find your interface name using `ip link` or `ifconfig`
INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n 1)

# Check if the interface exists
if [ -z "$INTERFACE" ]; then
    echo '{"text": "No Net", "tooltip": "No active network interface found."}'
    exit 0
fi

# Function to convert bytes to human-readable format
human_readable_bytes() {
    local bytes=$1
    local units=("B/s" "KB/s" "MB/s" "GB/s" "TB/s")
    local i=0
    while (( $(echo "$bytes >= 1024" | bc -l) && i < ${#units[@]} - 1 )); do
        bytes=$(echo "scale=2; $bytes / 1024" | bc -l)
        i=$((i + 1))
    done
    printf "%.1f %s" "$bytes" "${units[$i]}"
}

# Read current rx and tx bytes
read rx_bytes_prev tx_bytes_prev < <(awk -v OFS=" " '$1 == "'"$INTERFACE"':'" {print $2, $10}' /proc/net/dev)

# Wait for 1 second to calculate speed
sleep 1

# Read new rx and tx bytes
read rx_bytes_curr tx_bytes_curr < <(awk -v OFS=" " '$1 == "'"$INTERFACE"':'" {print $2, $10}' /proc/net/dev)

# Calculate speeds
download_speed=$(echo "$rx_bytes_curr - $rx_bytes_prev" | bc)
upload_speed=$(echo "$tx_bytes_curr - $tx_bytes_prev" | bc)

# Convert to human-readable format
download_speed_human=$(human_readable_bytes "$download_speed")
upload_speed_human=$(human_readable_bytes "$upload_speed")

# Output JSON
cat <<EOF
{
    "text": "${upload_speed_human} ${download_speed_human}",
    "tooltip": "Upload: ${upload_speed_human}\nDownload: ${download_speed_human}",
    "upload": "${upload_speed_human}",
    "download": "${download_speed_human}",
    "upload_full": "${upload_speed_human}",
    "download_full": "${download_speed_human}"
}
EOF
