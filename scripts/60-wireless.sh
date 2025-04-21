#!/usr/bin/fish
# FastWrt wireless configuration script - Fish shell implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting wireless configuration script..."

# Load passphrases from file
if test -f "$BASE_DIR/passphrases.fish"
    source "$BASE_DIR/passphrases.fish"
else
    echo "ERROR: Fish-compatible passphrases file not found!"
    exit 1
end

# Add debugging statements to log variable values
echo "SSID_OPENWRT: $SSID_OPENWRT"
echo "PASSPHRASE_OPENWRT: $PASSPHRASE_OPENWRT"
echo "SSID_CLOSEDWRT: $SSID_CLOSEDWRT"
echo "PASSPHRASE_CLOSEDWRT: $PASSPHRASE_CLOSEDWRT"
echo "SSID_IOTWRT: $SSID_IOTWRT"
echo "PASSPHRASE_IOTWRT: $PASSPHRASE_IOTWRT"
echo "SSID_METAWRT: $SSID_METAWRT"
echo "PASSPHRASE_METAWRT: $PASSPHRASE_METAWRT"

# Clear existing wireless interfaces
echo "Clearing existing wireless configuration..."
while uci -q delete wireless.@wifi-iface[0] > /dev/null 2>&1
    echo "Deleted wireless.@wifi-iface[0]."
end
echo "All wifi-iface entries cleared."

# Configure 2.4GHz radio
echo "Configuring 2.4GHz radio (radio0)..."
uci set wireless.radio0='wifi-device'
uci set wireless.radio0.channel='1'
uci set wireless.radio0.band='2g'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='SE'  # Adjust country code as needed

# Configure 5GHz radio
echo "Configuring 5GHz radio (radio1)..."
uci set wireless.radio1='wifi-device'
uci set wireless.radio1.channel='36'
uci set wireless.radio1.band='5g'
uci set wireless.radio1.htmode='VHT80'
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='SE'  # Adjust country code as needed

# Commit wireless settings before creating interfaces
uci commit wireless

# Configure interfaces for each SSID
# Assign IoT to 2G radio
echo "Creating IOT network on 2.4GHz..."
uci set wireless.wifinet0='wifi-iface'
uci set wireless.wifinet0.device='radio0'
uci set wireless.wifinet0.mode='ap'
uci set wireless.wifinet0.ssid="$SSID_IOTWRT"
uci set wireless.wifinet0.key="$PASSPHRASE_IOTWRT"
uci set wireless.wifinet0.encryption='psk2'
uci set wireless.wifinet0.network='iot'  # Connect to IOT network
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet0.macfilter='disable'
echo "IoT assigned"

# Assign OpenWrt to guest network on both radios
echo "Configuring OpenWrt SSID on both radios..."
uci set wireless.wifinet1='wifi-iface'
uci set wireless.wifinet1.device='radio0'
uci set wireless.wifinet1.mode='ap'
uci set wireless.wifinet1.ssid="$SSID_OPENWRT"
uci set wireless.wifinet1.key="$PASSPHRASE_OPENWRT"
uci set wireless.wifinet1.encryption='psk2'
uci set wireless.wifinet1.network='guest'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet1.macfilter='disable'
#
uci set wireless.wifinet2='wifi-iface'
uci set wireless.wifinet2.device='radio1'
uci set wireless.wifinet2.mode='ap'
uci set wireless.wifinet2.ssid="$SSID_OPENWRT"
uci set wireless.wifinet2.key="$PASSPHRASE_OPENWRT"
uci set wireless.wifinet2.encryption='psk2'
uci set wireless.wifinet2.network='guest'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet2.macfilter='disable'
echo "OpenWrt assigned"

# Assign ClosedWrt to core network on both radios
echo "Configuring ClosedWrt SSID on both radios..."
uci set wireless.wifinet3='wifi-iface'
uci set wireless.wifinet3.device='radio0'
uci set wireless.wifinet3.mode='ap'
uci set wireless.wifinet3.ssid="$SSID_CLOSEDWRT"
uci set wireless.wifinet3.key="$PASSPHRASE_CLOSEDWRT"
uci set wireless.wifinet3.encryption='psk2'
uci set wireless.wifinet3.network='core'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet3.macfilter='disable'
#
uci set wireless.wifinet4='wifi-iface'
uci set wireless.wifinet4.device='radio1'
uci set wireless.wifinet4.mode='ap'
uci set wireless.wifinet4.ssid="$SSID_CLOSEDWRT"
uci set wireless.wifinet4.key="$PASSPHRASE_CLOSEDWRT"
uci set wireless.wifinet4.encryption='psk2'
uci set wireless.wifinet4.network='core'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet4.macfilter='disable'
echo "ClosedWrt assigned"

# Assign MetaWrt to 5G radio only
echo "Configuring MetaWrt SSID on 5G radio..."
uci set wireless.wifinet5='wifi-iface'
uci set wireless.wifinet5.device='radio1'
uci set wireless.wifinet5.mode='ap'
uci set wireless.wifinet5.ssid="$SSID_METAWRT"
uci set wireless.wifinet5.key="$PASSPHRASE_METAWRT"
uci set wireless.wifinet5.encryption='psk2'
uci set wireless.wifinet5.network='meta'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet5.macfilter='disable'
echo "MetaWrt assigned"

# Enable 2G radio
echo "[INFO] Enabling 2G radio..."
uci set wireless.radio0.disabled='0'
echo "[SUCCESS] 2G radio enabled successfully."

# Enable 5G radio
echo "[INFO] Enabling 5G radio..."
uci set wireless.radio1.disabled='0'
echo "[SUCCESS] 5G radio enabled successfully."

# Process the maclist file line by line
set MACLIST_PATH "$BASE_DIR/maclist.csv"
if test -f "$MACLIST_PATH"
  echo "Maclist file found at: $MACLIST_PATH"
  
  while read -l line
    # Skip comment lines and empty lines
    if string match -q "#*" $line; or test -z "$line"
      continue
    end
    
    # Parse CSV line (mac,ip,name,network)
    set fields (string split "," $line)
    set mac_addr $fields[1]
    set ip_addr $fields[2]
    set device_name $fields[3]
    set network_name $fields[4]
    
    echo "Processing MAC entry: MAC=$mac_addr, IP=$ip_addr, Name=$device_name, Network=$network_name"
    
    # Skip non-wifi devices (those with names ending in -eth)
    if string match -q "*-eth" "$device_name"
      echo "Skipping Ethernet device: $device_name ($mac_addr)"
      continue
    end
    
    # Always add MAC to the appropriate maclist for future reference
    switch "$network_name"
      case core
        uci add_list wireless.wifinet3.maclist "$mac_addr"
        uci add_list wireless.wifinet4.maclist "$mac_addr"
        
      case guest
        uci add_list wireless.wifinet1.maclist "$mac_addr"
        uci add_list wireless.wifinet2.maclist "$mac_addr"
        
      case meta
        uci add_list wireless.wifinet5.maclist "$mac_addr"
        
      case iot
        uci add_list wireless.wifinet0.maclist "$mac_addr"
        
      case '*'
        echo "Skipping MAC $mac_addr - no valid network specified ($network_name)"
    end
  end < "$MACLIST_PATH"
else
  echo "Maclist file not found at: $MACLIST_PATH"
end

# Create enable_mac_filtering script for later activation
echo "Creating utility script to enable MAC filtering when ready..."
echo '#!/usr/bin/fish
echo "Starting MAC filtering activation script..."

# Configure wireless interfaces to use the MAC filtering
echo "Setting MAC filters to allow mode..."
uci set wireless.wifinet0.macfilter="allow"
uci set wireless.wifinet1.macfilter="allow"
uci set wireless.wifinet2.macfilter="allow"
uci set wireless.wifinet3.macfilter="allow"
uci set wireless.wifinet4.macfilter="allow"
uci set wireless.wifinet5.macfilter="allow"

# Commit changes and reload wireless configuration
uci commit wireless
wifi reload

echo "MAC filtering has been enabled. Only devices in the maclist.csv will now be allowed to connect."
' > "$BASE_DIR/enable_mac_filtering.sh"

chmod +x "$BASE_DIR/enable_mac_filtering.sh"
echo "Created utility script $BASE_DIR/enable_mac_filtering.sh to enable MAC filtering when ready."

# Commit changes and reload wireless configuration
uci commit wireless
wifi reload

echo "Wireless configuration script completed successfully."
echo "NOTE: MAC filtering is currently DISABLED. Run enable_mac_filtering.sh when you're ready to activate it."
