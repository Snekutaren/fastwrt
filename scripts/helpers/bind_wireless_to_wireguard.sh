#!/bin/sh
# Script to create a wireless network bound to a WireGuard interface
# This bypasses the "Indoor Only Channel Selected" error by using direct UCI commands

echo "===== Creating Wireless Network Bound to WireGuard ====="
echo "This script creates a wireless network that routes traffic through your WireGuard interface"

# Check if we have a command line argument for SSID
if [ -z "$1" ]; then
  echo "Usage: $0 <ssid> <password> [encryption] [wireguard_interface]"
  echo "Example: $0 MyWirelessNetwork MySecurePassword psk2 wg0"
  echo "Default encryption is psk2 (WPA2-PSK)"
  echo "Default WireGuard interface is wg0"
  exit 1
fi

# Assign arguments to variables
SSID="$1"
PASSWORD="$2"
ENCRYPTION="${3:-psk2}"  # Default to WPA2-PSK
WG_INTERFACE="${4:-wg0}"  # Default to wg0

# Check if WireGuard interface exists
if ! uci show network."$WG_INTERFACE" > /dev/null 2>&1; then
  echo "Error: WireGuard interface $WG_INTERFACE not found."
  echo "Available interfaces:"
  uci show network | grep "=interface" | cut -d'.' -f2 | cut -d'=' -f1
  exit 1
fi

# Generate a unique name for the wireless network
NETWORK_NAME="wgwifi_$(date +%s | tail -c 6)"

# First, create a new network interface tied to WireGuard
echo "Creating new network interface tied to WireGuard..."
uci set network."$NETWORK_NAME"=interface
uci set network."$NETWORK_NAME".proto='none'
uci set network."$NETWORK_NAME".device="$WG_INTERFACE"

# Create wireless networks for both radios
for radio in radio0 radio1; do
  # Check if radio exists
  if uci show wireless."$radio" > /dev/null 2>&1; then
    # Generate unique name for each wireless network
    wifi_name="${NETWORK_NAME}_${radio}"
    
    echo "Creating wireless network '$SSID' on $radio..."
    
    # Create the wireless network
    uci set wireless."$wifi_name"=wifi-iface
    uci set wireless."$wifi_name".device="$radio"
    uci set wireless."$wifi_name".network="$NETWORK_NAME"
    uci set wireless."$wifi_name".mode='ap'
    uci set wireless."$wifi_name".ssid="$SSID"
    
    # Set encryption if password is provided
    if [ -n "$PASSWORD" ]; then
      uci set wireless."$wifi_name".encryption="$ENCRYPTION"
      uci set wireless."$wifi_name".key="$PASSWORD"
    else
      uci set wireless."$wifi_name".encryption='none'
    fi
    
    # Enable the radio if it's disabled
    if [ "$(uci -q get wireless."$radio".disabled)" = "1" ]; then
      echo "Enabling $radio..."
      uci set wireless."$radio".disabled='0'
    fi
  else
    echo "Radio $radio not found, skipping."
  fi
done

# Commit changes and reload
echo "Committing changes..."
uci commit network
uci commit wireless

echo "Reloading network and wireless configurations..."
/etc/init.d/network reload
wifi reload

echo
echo "===== Wireless Network Setup Complete ====="
echo "SSID: $SSID"
if [ -n "$PASSWORD" ]; then
  echo "Password: $PASSWORD"
  echo "Encryption: $ENCRYPTION"
else
  echo "No password (open network)"
fi
echo "Network: $NETWORK_NAME (bound to $WG_INTERFACE)"
echo
echo "All traffic on this wireless network will be routed through your WireGuard VPN."
echo "To verify, connect to the network and check your public IP address."
echo
echo "If you need to remove this network later, run:"
echo "uci delete network.$NETWORK_NAME"
echo "uci delete wireless.${NETWORK_NAME}_radio0"
echo "uci delete wireless.${NETWORK_NAME}_radio1"
echo "uci commit network wireless"
echo "wifi reload"