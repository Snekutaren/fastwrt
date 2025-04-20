#!/bin/sh

set -e  # Exit on any error

# Ensure the script runs from its own directory
cd "$BASE_DIR"

# Debugging: Log the current working directory
echo "Current working directory: $(pwd)"

# Process the maclist file line by line instead of sourcing it
MACLIST_PATH="$BASE_DIR/maclist"
if [ -f "$MACLIST_PATH" ]; then
  echo "Maclist file found at: $MACLIST_PATH"
  while IFS= read -r line; do
    # Process each line of the maclist file
    echo "Processing line: $line"
    mac=$(echo "$line" | cut -d',' -f1)
    ip=$(echo "$line" | cut -d',' -f2)
    hostname=$(echo "$line" | cut -d',' -f3)
    ssid=$(echo "$line" | cut -d',' -f4)
    # Add logic to handle the extracted values as needed
    echo "MAC: $mac, IP: $ip, Hostname: $hostname, SSID: $ssid"
  done < "$MACLIST_PATH"
else
  echo "Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist' file."
  exit 1
fi

# Log the purpose of the script
echo "Starting wireless configuration script to set up Wi-Fi settings..."

# Configure Wi-Fi settings for each SSID
uci set wireless.@wifi-iface[0].ssid="$SSID_OPENWRT"
uci set wireless.@wifi-iface[0].key="$PASSPHRASE_OPENWRT"
uci set wireless.@wifi-iface[0].encryption="psk2"

uci set wireless.@wifi-iface[1].ssid="$SSID_CLOSEDWRT"
uci set wireless.@wifi-iface[1].key="$PASSPHRASE_CLOSEDWRT"
uci set wireless.@wifi-iface[1].encryption="psk2"

uci set wireless.@wifi-iface[2].ssid="$SSID_IOTWRT"
uci set wireless.@wifi-iface[2].key="$PASSPHRASE_IOTWRT"
uci set wireless.@wifi-iface[2].encryption="psk2"

uci set wireless.@wifi-iface[3].ssid="$SSID_METAWRT"
uci set wireless.@wifi-iface[3].key="$PASSPHRASE_METAWRT"
uci set wireless.@wifi-iface[3].encryption="psk2"

# Assign each Wi-Fi interface to the appropriate firewall zone
uci set wireless.@wifi-iface[0].network="guest"
uci set wireless.@wifi-iface[1].network="core"
uci set wireless.@wifi-iface[2].network="iot"
uci set wireless.@wifi-iface[3].network="meta"

# MAC Filtering and SSID Assignment Logic
# Update MAC filtering logic to skip entries with empty SSID field
if [ "$ENABLE_MAC_FILTERING" = true ]; then
  echo "MAC filtering is enabled. Reading allow list from external file..."
  if [ -f "maclist" ]; then
    while IFS= read -r line; do
      mac=$(echo "$line" | cut -d',' -f1)
      ssid=$(echo "$line" | cut -d',' -f4)
      if [ -n "$mac" ] && [ -n "$ssid" ]; then
        echo "Adding MAC: $mac to SSID: $ssid allow list..."
        case "$ssid" in
          "OpenWrt")
            uci add_list wireless.@wifi-iface[0].maclist="$mac"
            ;;
          "ClosedWrt")
            uci add_list wireless.@wifi-iface[1].maclist="$mac"
            ;;
          "IoTWrt")
            uci add_list wireless.@wifi-iface[2].maclist="$mac"
            ;;
          "MetaWrt")
            uci add_list wireless.@wifi-iface[3].maclist="$mac"
            ;;
          *)
            echo "Unknown SSID: $ssid. Skipping MAC: $mac."
            ;;
        esac
      fi
    done < maclist
    # Enable MAC filtering for all SSIDs
    for iface in 0 1 2 3; do
      uci set wireless.@wifi-iface[$iface].macfilter="allow"
    done
  else
    echo "MAC list file not found. Please create a 'maclist' file with MAC,SSID entries."
    exit 1
  fi
else
  echo "MAC filtering is disabled."
  for iface in 0 1 2 3; do
    uci set wireless.@wifi-iface[$iface].macfilter="none"
  done
fi

# Commit the changes and reload the wireless configuration
uci commit wireless
wifi reload

# Log the completion of the zone assignment
echo "Wi-Fi interfaces assigned to firewall zones successfully."