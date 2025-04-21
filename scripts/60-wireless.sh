#!/bin/sh
set -e  # Exit on any error
# Ensure the script runs from its own directory
cd "$BASE_DIR"
echo "Current working directory: $(pwd)"

# Log the purpose of the script
echo "Starting wireless configuration script to set up Wi-Fi settings..."

# Add debugging statements to log variable values
echo "SSID_OPENWRT: $SSID_OPENWRT"
echo "PASSPHRASE_OPENWRT: $PASSPHRASE_OPENWRT"
echo "SSID_CLOSEDWRT: $SSID_CLOSEDWRT"
echo "PASSPHRASE_CLOSEDWRT: $PASSPHRASE_CLOSEDWRT"
echo "SSID_IOTWRT: $SSID_IOTWRT"
echo "PASSPHRASE_IOTWRT: $PASSPHRASE_IOTWRT"
echo "SSID_METAWRT: $SSID_METAWRT"
echo "PASSPHRASE_METAWRT: $PASSPHRASE_METAWRT"

# Clear all existing wifi-iface entries
echo "Clearing all existing wifi-iface entries..."
while uci -q delete wireless.@wifi-iface[0]; do
  echo "Deleted wireless.@wifi-iface[0]."
done
echo "All wifi-iface entries cleared."

# Configure 2G radio (radio0)
uci set wireless.radio0=wifi-device
uci set wireless.radio0.channel='1'
uci set wireless.radio0.band='2g'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='SE'  # Adjust country code as needed

# Configure 5G radio (radio1)
uci set wireless.radio1=wifi-device
uci set wireless.radio1.channel='36'
uci set wireless.radio1.band='5g'
uci set wireless.radio1.htmode='VHT80'
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='SE'  # Adjust country code as needed

# Commit changes
uci commit wireless

# Configure interfaces for each SSID
# Assign IoT to 2G radio
echo "Configuring IoT SSID on 2G radio..."
uci set wireless.wifinet0=wifi-iface
uci set wireless.wifinet0.device='radio0'
uci set wireless.wifinet0.mode='ap'
uci set wireless.wifinet0.ssid="$SSID_IOTWRT"
uci set wireless.wifinet0.key="$PASSPHRASE_IOTWRT"
uci set wireless.wifinet0.encryption='psk2'
uci set wireless.wifinet0.network='iot'
echo "IoT assigned"

# Assign OpenWrt to guest network on both radios
echo "Configuring OpenWrt SSID on both radios..."
uci set wireless.wifinet1=wifi-iface
uci set wireless.wifinet1.device='radio0'
uci set wireless.wifinet1.mode='ap'
uci set wireless.wifinet1.ssid="$SSID_OPENWRT"
uci set wireless.wifinet1.key="$PASSPHRASE_OPENWRT"
uci set wireless.wifinet1.encryption='psk2'
uci set wireless.wifinet1.network='guest'
#
uci set wireless.wifinet2=wifi-iface
uci set wireless.wifinet2.device='radio1'
uci set wireless.wifinet2.mode='ap'
uci set wireless.wifinet2.ssid="$SSID_OPENWRT"
uci set wireless.wifinet2.key="$PASSPHRASE_OPENWRT"
uci set wireless.wifinet2.encryption='psk2'
uci set wireless.wifinet2.network='guest'
echo "OpenWrt assigned"

# Assign ClosedWrt to core network on both radios
echo "Configuring ClosedWrt SSID on both radios..."
uci set wireless.wifinet3=wifi-iface
uci set wireless.wifinet3.device='radio0'
uci set wireless.wifinet3.mode='ap'
uci set wireless.wifinet3.ssid="$SSID_CLOSEDWRT"
uci set wireless.wifinet3.key="$PASSPHRASE_CLOSDEWRT"
uci set wireless.wifinet3.encryption='psk2'
uci set wireless.wifinet3.network='core'
#
uci set wireless.wifinet4=wifi-iface
uci set wireless.wifinet4.device='radio1'
uci set wireless.wifinet4.mode='ap'
uci set wireless.wifinet4.ssid="$SSID_CLOSEDWRT"
uci set wireless.wifinet4.key="$PASSPHRASE_CLOSEDWRT"
uci set wireless.wifinet4.encryption='psk2'
uci set wireless.wifinet4.network='core'
echo "ClosedWrt assigned"

# Assign MetaWrt to 5G radio only
echo "Configuring MetaWrt SSID on 5G radio..."
uci set wireless.wifinet5=wifi-iface
uci set wireless.wifinet5.device='radio1'
uci set wireless.wifinet5.mode='ap'
uci set wireless.wifinet5.ssid="$SSID_METAWRT"
uci set wireless.wifinet5.key="$PASSPHRASE_METAWRT"
uci set wireless.wifinet5.encryption='psk3'
uci set wireless.wifinet5.network='meta'
echo "MetaWrt assigned"

# Enable 2G radio
echo "[INFO] Enabling 2G radio..."
uci set wireless.radio0.disabled='0'
echo "[SUCCESS] 2G radio enabled successfully."

# Enable 5G radio
echo "[INFO] Enabling 5G radio..."
uci set wireless.radio1.disabled='0'
echo "[SUCCESS] 5G radio enabled successfully."

# Process the maclist file line by line instead of sourcing it
MACLIST_PATH="$BASE_DIR/maclist.csv"
if [ -f "$MACLIST_PATH" ]; then
  echo "Maclist file found at: $MACLIST_PATH"
  while IFS=, read -r mac_addr ip_addr device_name network_name; do
    # Skip comment lines and empty lines
    case "$mac_addr" in
      \#*|"") continue ;;
    esac
    
    echo "Processing MAC entry: MAC=$mac_addr, IP=$ip_addr, Name=$device_name, Network=$network_name"
    
    # Skip non-wifi devices (those with names ending in -eth)
    case "$device_name" in
      *-eth)
        echo "Skipping Ethernet device: $device_name ($mac_addr)"
        continue
        ;;
    esac
    
    # Always add MAC to the allow list for the correct wifi-iface(s)
    case "$network_name" in
      core)
        uci add_list wireless.wifinet3.maclist="$mac_addr"
        uci add_list wireless.wifinet4.maclist="$mac_addr"
        if [ "$ENABLE_MAC_FILTERING" = "true" ]; then
          uci set wireless.wifinet3.macfilter='allow'
          uci set wireless.wifinet4.macfilter='allow'
        fi
        ;;
      guest)
        uci add_list wireless.wifinet1.maclist="$mac_addr"
        uci add_list wireless.wifinet2.maclist="$mac_addr"
        if [ "$ENABLE_MAC_FILTERING" = "true" ]; then
          uci set wireless.wifinet1.macfilter='allow'
          uci set wireless.wifinet2.macfilter='allow'
        fi
        ;;
      meta)
        uci add_list wireless.wifinet5.maclist="$mac_addr"
        if [ "$ENABLE_MAC_FILTERING" = "true" ]; then
          uci set wireless.wifinet5.macfilter='allow'
        fi
        ;;
      iot)
        uci add_list wireless.wifinet0.maclist="$mac_addr"
        if [ "$ENABLE_MAC_FILTERING" = "true" ]; then
          uci set wireless.wifinet0.macfilter='allow'
        fi
        ;;
      *)
        echo "Skipping MAC $mac_addr - no valid network specified ($network_name)"
        ;;
    esac
  done < "$MACLIST_PATH"
else
  echo "Maclist file not found at: $MACLIST_PATH"
fi

# Commit changes and reload wireless configuration
uci commit wireless
wifi reload

echo "Wireless configuration script completed successfully."
