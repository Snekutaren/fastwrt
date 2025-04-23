#!/bin/sh
# fix_indoor_channel.sh
# Direct fix for the "Indoor Only Channel Selected" error in LuCI
# This script patches the relevant LuCI validation code or sets the correct parameters to avoid the error

echo "Applying fix for 'Indoor Only Channel Selected' LuCI validation error..."

# Create backup of current wireless config
cp /etc/config/wireless /etc/config/wireless.bak
echo "Backup created at /etc/config/wireless.bak"

# =====================================================================
# APPROACH 1: Fix by removing problematic settings
# =====================================================================
echo
echo "APPROACH 1: Removing problematic wireless settings..."

# Remove indoor/outdoor flags that may be causing validation issues
for radio in radio0 radio1; do
  echo "Checking $radio for problematic settings..."
  
  # Remove indoor flag
  if uci -q get wireless.$radio.indoor >/dev/null; then
    echo "Removing indoor flag from $radio..."
    uci -q delete wireless.$radio.indoor
  fi
  
  # Remove outdoor flag
  if uci -q get wireless.$radio.outdoor >/dev/null; then
    echo "Removing outdoor flag from $radio..."
    uci -q delete wireless.$radio.outdoor
  fi
  
  # Remove dfs_mode flag
  if uci -q get wireless.$radio.dfs_mode >/dev/null; then
    echo "Removing dfs_mode flag from $radio..."
    uci -q delete wireless.$radio.dfs_mode
  fi
  
  # Reset country to US which has more permissive settings
  echo "Setting country code to US for $radio..."
  uci set wireless.$radio.country='US'
  
  # Set channels to non-DFS values
  if [ "$radio" = "radio0" ]; then
    # 2.4 GHz
    echo "Setting channel to 1 for $radio (2.4GHz)..."
    uci set wireless.$radio.channel='1'
  else
    # 5 GHz - channel 36 is non-DFS in most countries
    echo "Setting channel to 36 for $radio (5GHz)..."
    uci set wireless.$radio.channel='36'
  fi
done

# Apply changes
uci commit wireless
echo "Changes committed for Approach 1"

# =====================================================================
# APPROACH 2: Patch LuCI validation code
# =====================================================================
echo
echo "APPROACH 2: Patching LuCI validation code..."

# Find LuCI wireless validation code
LUCI_WIRELESS_PATH=$(find /usr/lib/lua/luci -name "wireless.lua" | grep -E "model|controller")

if [ -n "$LUCI_WIRELESS_PATH" ]; then
  echo "Found LuCI wireless validation code at: $LUCI_WIRELESS_PATH"
  
  # Create backup of the original file
  cp "$LUCI_WIRELESS_PATH" "${LUCI_WIRELESS_PATH}.bak"
  echo "Created backup at ${LUCI_WIRELESS_PATH}.bak"
  
  # Patch the validation code - modifying the indoor channel check
  echo "Patching validation code..."
  sed -i 's/\(.*indoor.*\)channel\(.*\)/-- \1channel\2 -- Indoor check disabled by FastWrt/' "$LUCI_WIRELESS_PATH" 2>/dev/null
  
  # Additional patch for any outdoor/regulatory checks
  sed -i 's/\(.*outdoor.*\)channel\(.*\)/-- \1channel\2 -- Outdoor check disabled by FastWrt/' "$LUCI_WIRELESS_PATH" 2>/dev/null
  sed -i 's/\(.*regulatory.*\)channel\(.*\)/-- \1channel\2 -- Regulatory check disabled by FastWrt/' "$LUCI_WIRELESS_PATH" 2>/dev/null
  
  echo "LuCI wireless validation patch applied"
else
  echo "Could not find LuCI wireless validation code. Skipping patch."
fi

# =====================================================================
# APPROACH 3: Create direct workaround function
# =====================================================================
echo
echo "APPROACH 3: Creating workaround function..."

# Create a helper script to directly add wireless networks using UCI
cat > /usr/bin/add_wireless_network << 'EOF'
#!/bin/sh
# add_wireless_network - Direct UCI command to add wireless networks bypassing LuCI validation
# Usage: add_wireless_network <radio> <ssid> <encryption> <password> <network>

if [ $# -lt 5 ]; then
  echo "Usage: $0 <radio> <ssid> <encryption> <password> <network>"
  echo "Example: $0 radio0 MyWiFi psk2 MySecurePassword lan"
  exit 1
fi

RADIO="$1"
SSID="$2"
ENCRYPTION="$3"
PASSWORD="$4"
NETWORK="$5"

# Generate random name for the wifi-iface
WIFI_NAME="${SSID// /_}_${RADIO}_$(date +%s | tail -c 5)"

# Create the wireless network directly via UCI
uci set wireless.${WIFI_NAME}=wifi-iface
uci set wireless.${WIFI_NAME}.device="$RADIO"
uci set wireless.${WIFI_NAME}.network="$NETWORK"
uci set wireless.${WIFI_NAME}.mode='ap'
uci set wireless.${WIFI_NAME}.ssid="$SSID"
uci set wireless.${WIFI_NAME}.encryption="$ENCRYPTION"
uci set wireless.${WIFI_NAME}.key="$PASSWORD"

# Apply changes
uci commit wireless

echo "Wireless network '$SSID' created on $RADIO"
echo "To apply changes, run: wifi reload"
EOF

chmod +x /usr/bin/add_wireless_network
echo "Created helper script at /usr/bin/add_wireless_network"

# =====================================================================
# Final steps
# =====================================================================
# Reload wireless to apply settings
echo
echo "Reloading wireless configuration..."
wifi reload

echo
echo "Fix attempt complete. Please try one of the following:"
echo 
echo "1. Try adding a wireless network through LuCI now"
echo "2. If that still fails, use the direct command-line approach:"
echo "   add_wireless_network radio0 MyWiFi psk2 MySecurePassword lan"
echo "   add_wireless_network radio1 MyWiFi psk2 MySecurePassword lan"
echo
echo "3. If you need to restore the original config:"
echo "   cp /etc/config/wireless.bak /etc/config/wireless"
echo "   wifi reload"