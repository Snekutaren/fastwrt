#!/usr/bin/fish
# FastWrt wireless configuration script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the purpose of the script
echo "$purple""Starting wireless configuration script...""$reset"

# Load passphrases from file
if test -f "$BASE_DIR/passphrases.fish"
    source "$BASE_DIR/passphrases.fish"
    echo "$green""Loaded passphrases from $BASE_DIR/passphrases.fish""$reset"
else
    echo "$red""ERROR: Fish-compatible passphrases file not found!""$reset"
    exit 1
end

# Add support for alternative config directory structure (future implementation)
# This will allow loading configuration from a modular directory structure
if test -d "$BASE_DIR/config" -a -f "$BASE_DIR/config/config_paths.fish"
    # Future implementation will load from structured config directories
    echo "$yellow""Modular configuration directory detected - this feature will be supported in a future update""$reset"
    # To be implemented: source "$BASE_DIR/config/config_paths.fish"
end

# Add debugging statements to log variable values
if test "$DEBUG" = "true"
    echo "$yellow""SSID_OPENWRT: $SSID_OPENWRT""$reset"
    echo "$yellow""PASSPHRASE_OPENWRT: $PASSPHRASE_OPENWRT""$reset"
    echo "$yellow""SSID_CLOSEDWRT: $SSID_CLOSEDWRT""$reset"
    echo "$yellow""PASSPHRASE_CLOSEDWRT: $PASSPHRASE_CLOSEDWRT""$reset"
    echo "$yellow""SSID_IOTWRT: $SSID_IOTWRT""$reset"
    echo "$yellow""PASSPHRASE_IOTWRT: $PASSPHRASE_IOTWRT""$reset"
    echo "$yellow""SSID_METAWRT: $SSID_METAWRT""$reset"
    echo "$yellow""PASSPHRASE_METAWRT: $PASSPHRASE_METAWRT""$reset"
else
    # Just show SSIDs in normal mode, without passphrases
    echo "$blue""Configuring wireless networks with SSIDs:""$reset"
    echo "$blue""- $SSID_OPENWRT""$reset"
    echo "$blue""- $SSID_CLOSEDWRT""$reset"
    echo "$blue""- $SSID_IOTWRT""$reset"
    echo "$blue""- $SSID_METAWRT""$reset"
end

# Clear existing wireless interfaces with improved output
set wifi_iface_count 0
echo "$blue""Clearing existing wireless configuration...""$reset"
while uci -q delete wireless.@wifi-iface[0] > /dev/null
  set wifi_iface_count (math $wifi_iface_count + 1)
  if test "$DEBUG" = "true"
    echo "$yellow""Deleted wireless.@wifi-iface[0]""$reset"
  end
end
echo "$green""Cleared $wifi_iface_count wireless interface entries""$reset"

# Configure 2.4GHz radio
echo "$blue""Configuring 2.4GHz radio (radio0)...""$reset"
uci set wireless.radio0='wifi-device'
uci set wireless.radio0.channel='1'
uci set wireless.radio0.band='2g'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country='SE'  # Adjust country code as needed
# Fix for Indoor Only Channel issue - explicitly set indoor/outdoor mode
uci set wireless.radio0.indoor='1'  # Set to 1 for indoor use, 0 for outdoor
uci set wireless.radio0.cell_density='0'  # 0=default density
echo "$green""2.4GHz radio configured.""$reset"

# Configure 5GHz radio
echo "$blue""Configuring 5GHz radio (radio1)...""$reset"
uci set wireless.radio1='wifi-device'
uci set wireless.radio1.channel='36'  # Using a commonly allowed indoor channel
uci set wireless.radio1.band='5g'
uci set wireless.radio1.htmode='VHT80'
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country='SE'  # Adjust country code as needed
# Fix for Indoor Only Channel issue - explicitly set indoor/outdoor mode
uci set wireless.radio1.indoor='1'  # Set to 1 for indoor use, 0 for outdoor
uci set wireless.radio1.cell_density='0'  # 0=default density
echo "$green""5GHz radio configured.""$reset"

# Verify that all networks exist before configuring wireless interfaces
echo "$blue""Verifying all required networks exist...""$reset"
set required_networks core guest iot meta

# Check for missing networks
set missing_networks
for net in $required_networks
    if not uci -q get "network.$net" > /dev/null
        set -a missing_networks $net
    end
end

if test (count $missing_networks) -gt 0
    echo "$red""ERROR: The following required networks are missing: ""$reset"(string join ", " $missing_networks)
    echo "$red""Network interfaces must be properly configured in 30-network.sh before wireless configuration.""$reset"
    echo "$red""Aborting wireless configuration to prevent inconsistent state.""$reset"
    exit 1
else
    echo "$green""All required networks exist, proceeding with wireless configuration.""$reset"
end

# Configure interfaces for each SSID
# Assign IoT to 2G radio
echo "$blue""Creating IOT network on 2.4GHz...""$reset"
uci set wireless.wifinet0='wifi-iface'
uci set wireless.wifinet0.device='radio0'
uci set wireless.wifinet0.mode='ap'
uci set wireless.wifinet0.ssid="$SSID_IOTWRT"
uci set wireless.wifinet0.key="$PASSPHRASE_IOTWRT"
uci set wireless.wifinet0.encryption='psk2'  # WPA2-PSK encryption
uci set wireless.wifinet0.network='iot'  # Connect to IOT network

# Initialize macfilter to 'disable' by default - will be enabled later in script
uci set wireless.wifinet0.macfilter='disable'
echo "$green""IoT network assigned with WPA2-PSK encryption (MAC filtering will be enabled)""$reset"

# Assign OpenWrt to guest network on both radios
echo "$blue""Configuring OpenWrt SSID on both radios...""$reset"
uci set wireless.wifinet1='wifi-iface'
uci set wireless.wifinet1.device='radio0'
uci set wireless.wifinet1.mode='ap'
uci set wireless.wifinet1.ssid="$SSID_OPENWRT"
uci set wireless.wifinet1.key="$PASSPHRASE_OPENWRT"
uci set wireless.wifinet1.encryption='psk2'  # WPA2-PSK encryption
uci set wireless.wifinet1.network='guest'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet1.macfilter='disable'
#
uci set wireless.wifinet2='wifi-iface'
uci set wireless.wifinet2.device='radio1'
uci set wireless.wifinet2.mode='ap'
uci set wireless.wifinet2.ssid="$SSID_OPENWRT"
uci set wireless.wifinet2.key="$PASSPHRASE_OPENWRT"
uci set wireless.wifinet2.encryption='psk2'  # WPA2-PSK encryption
uci set wireless.wifinet2.network='guest'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet2.macfilter='disable'
echo "$green""OpenWrt assigned with WPA2-PSK encryption""$reset"

# Assign ClosedWrt to core network on both radios
echo "$blue""Configuring ClosedWrt SSID on both radios...""$reset"
uci set wireless.wifinet3='wifi-iface'
uci set wireless.wifinet3.device='radio0'
uci set wireless.wifinet3.mode='ap'
uci set wireless.wifinet3.ssid="$SSID_CLOSEDWRT"
uci set wireless.wifinet3.key="$PASSPHRASE_CLOSEDWRT"
uci set wireless.wifinet3.encryption='psk2'  # WPA2-PSK encryption
uci set wireless.wifinet3.network='core'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet3.macfilter='disable'
#
uci set wireless.wifinet4='wifi-iface'
uci set wireless.wifinet4.device='radio1'
uci set wireless.wifinet4.mode='ap'
uci set wireless.wifinet4.ssid="$SSID_CLOSEDWRT"
uci set wireless.wifinet4.key="$PASSPHRASE_CLOSEDWRT"
uci set wireless.wifinet4.encryption='psk2'  # WPA2-PSK encryption
uci set wireless.wifinet4.network='core'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet4.macfilter='disable'
echo "$green""ClosedWrt assigned with WPA2-PSK encryption""$reset"

# Assign MetaWrt to 5G radio only
echo "$blue""Configuring MetaWrt SSID on 5G radio...""$reset"
uci set wireless.wifinet5='wifi-iface'
uci set wireless.wifinet5.device='radio1'
uci set wireless.wifinet5.mode='ap'
uci set wireless.wifinet5.ssid="$SSID_METAWRT"
uci set wireless.wifinet5.key="$PASSPHRASE_METAWRT"
uci set wireless.wifinet5.encryption='sae'  # WPA3 encryption (SAE)
uci set wireless.wifinet5.network='meta'
# Initialize macfilter to 'disable' by default - devices can connect initially
uci set wireless.wifinet5.macfilter='disable'
echo "$green""MetaWrt assigned with WPA3-SAE encryption""$reset"

# Enable 2G radio
echo "$blue""[INFO] Enabling 2G radio...""$reset"
uci set wireless.radio0.disabled='0'
echo "$green""[SUCCESS] 2G radio enabled successfully.""$reset"

# Enable 5G radio
echo "$blue""[INFO] Enabling 5G radio...""$reset"
uci set wireless.radio1.disabled='0'
echo "$green""[SUCCESS] 5G radio enabled successfully.""$reset"

# Add debug-conditional processing for MAC list
set MACLIST_PATH "$BASE_DIR/maclist.csv"
if test -f "$MACLIST_PATH"
  echo "$green""Processing MAC filters from maclist.csv...""$reset"
  set mac_processing_errors 0
  set core_macs_count 0
  
  # First pass for core devices - reduce output unless debugging
  if test "$DEBUG" = "true"
    echo "$blue""First pass: identifying core devices...""$reset"
  end
  
  # First, collect all core/ClosedWrt MAC addresses
  set core_macs
  set mac_processing_errors 0
  
  echo "$blue""First pass: identifying core devices...""$reset"
  while read -l line
    # Skip comment lines and empty lines
    if string match -q "#*" $line; or test -z (string trim "$line")
      continue
    end
    
    # Parse CSV line (mac,ip,name,network)
    set fields (string split "," $line)
    
    # Skip lines with invalid format
    if test (count $fields) -lt 4
      echo "$yellow""Warning: Skipping line with invalid format: $line""$reset"
      set mac_processing_errors (math $mac_processing_errors + 1)
      continue
    end
    
    set mac_addr (string trim "$fields[1]")
    set device_name (string trim "$fields[3]")
    set network_name (string trim "$fields[4]")
    
    # Skip non-wifi devices (those with names ending in -eth)
    if string match -q "*-eth" "$device_name"
      continue
    end
    
    # Convert network name to lowercase for standardization
    set network_name_lower (string lower "$network_name")
    
    # Add to core_macs array if this is a core/ClosedWrt device
    if test "$network_name_lower" = "core" -o "$network_name_lower" = "closedwrt"
      set -a core_macs $mac_addr
      echo "$blue""Added $mac_addr to core devices list (from $network_name)""$reset"
    end
  end < "$MACLIST_PATH"
  
  echo "$blue""Second pass: assigning MACs to networks...""$reset"
  # Now process the maclist again and assign MACs to networks
  while read -l line
    # Skip comment lines and empty lines
    if string match -q "#*" $line; or test -z (string trim "$line")
      continue
    end
    
    # Parse CSV line (mac,ip,name,network)
    set fields (string split "," $line)
    
    # Skip lines with invalid format
    if test (count $fields) -lt 4
      continue
    end
    
    set mac_addr (string trim "$fields[1]")
    set ip_addr (string trim "$fields[2]")
    set device_name (string trim "$fields[3]")
    set network_name (string trim "$fields[4]")
    
    echo "$blue""Processing MAC entry: MAC=$mac_addr, IP=$ip_addr, Name=$device_name, Network=$network_name""$reset"
    
    # Skip non-wifi devices (those with names ending in -eth)
    if string match -q "*-eth" "$device_name"
      echo "$yellow""Skipping Ethernet device: $device_name ($mac_addr)""$reset"
      continue
    end
    
    # Convert network name to lowercase for standardization
    set network_name_lower (string lower "$network_name")
    
    # Map SSID names to network names if needed
    switch "$network_name_lower"
      case "closedwrt"
        set network_name "core"
      case "openwrt"
        set network_name "guest"
      case "iotwrt"
        set network_name "iot"
      case "metawrt"
        set network_name "meta"
    end
    
    echo "$blue""Adding MAC $mac_addr to $network_name network""$reset"
    
    # Add MAC to the appropriate maclist for its primary network
    switch "$network_name"
      case core
        uci add_list wireless.wifinet3.maclist="$mac_addr"
        uci add_list wireless.wifinet4.maclist="$mac_addr"
        
      case guest
        uci add_list wireless.wifinet1.maclist="$mac_addr"
        uci add_list wireless.wifinet2.maclist="$mac_addr"
        
      case meta
        uci add_list wireless.wifinet5.maclist="$mac_addr"
        
      case iot
        uci add_list wireless.wifinet0.maclist="$mac_addr"
        
      case '*'
        echo "$yellow""Skipping MAC $mac_addr - no valid network specified ($network_name)""$reset"
    end
  end < "$MACLIST_PATH"
  
  # Now add all core/ClosedWrt MACs to all other networks as well
  echo "$blue""Adding ClosedWrt devices to all networks' MAC allow lists...""$reset"
  for mac in $core_macs
    echo "$blue""Adding core device MAC $mac to all networks""$reset"
    # Add to guest network (OpenWrt)
    uci add_list wireless.wifinet1.maclist="$mac"
    uci add_list wireless.wifinet2.maclist="$mac"
    # Add to IoT network
    uci add_list wireless.wifinet0.maclist="$mac"
    # Add to Meta network
    uci add_list wireless.wifinet5.maclist="$mac"
  end
  
  # Always show summary stats
  echo "$green""Processed MAC filtering: added $core_macs_count core devices to all networks""$reset"
  if test $mac_processing_errors -gt 0
    echo "$yellow""Encountered $mac_processing_errors errors in MAC processing""$reset"
    if test "$DEBUG" != "true"
      echo "$yellow""Run with --debug for detailed error information""$reset"
    end
  end
else
  echo "$red""Maclist file not found at: $MACLIST_PATH""$reset"
end

# Directly enable MAC filtering by default
echo "$yellow""Enabling MAC filtering for all wireless networks...""$reset"
uci set wireless.wifinet0.macfilter='allow'
uci set wireless.wifinet1.macfilter='allow'
uci set wireless.wifinet2.macfilter='allow'
uci set wireless.wifinet3.macfilter='allow'
uci set wireless.wifinet4.macfilter='allow'
uci set wireless.wifinet5.macfilter='allow'
echo "$green""MAC filtering has been enabled. Only devices in the maclist will be allowed to connect.""$reset"

# Still create the enable_mac_filtering script for reference/restoration purposes,
# but don't advertise it in normal output
if test "$DEBUG" = "true"
    echo "$blue""Creating utility script to manage MAC filtering...""$reset"
    echo '#!/usr/bin/fish
# MAC filtering management script

# Set colors for readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set reset (echo -e "\033[0m")

if test "$1" = "enable"
    echo "$blue""Enabling MAC filtering...""$reset"
    uci set wireless.wifinet0.macfilter="allow"
    uci set wireless.wifinet1.macfilter="allow"
    uci set wireless.wifinet2.macfilter="allow"
    uci set wireless.wifinet3.macfilter="allow"
    uci set wireless.wifinet4.macfilter="allow"
    uci set wireless.wifinet5.macfilter="allow"
    echo "$green""MAC filtering enabled - only devices with allowed MAC addresses can connect""$reset"
elif test "$1" = "disable"
    echo "$red""Disabling MAC filtering...""$reset"
    echo "$red""WARNING: This will allow ANY device to connect to your networks!""$reset"
    echo "$yellow""Press Ctrl+C within 5 seconds to cancel...""$reset"
    sleep 5
    uci set wireless.wifinet0.macfilter="disable"
    uci set wireless.wifinet1.macfilter="disable"
    uci set wireless.wifinet2.macfilter="disable"
    uci set wireless.wifinet3.macfilter="disable"
    uci set wireless.wifinet4.macfilter="disable"
    uci set wireless.wifinet5.macfilter="disable"
    echo "$yellow""MAC filtering disabled - any device can now connect to your networks""$reset"
else
    echo "$blue""MAC Filtering Management Script""$reset"
    echo "$yellow""Usage: $0 [enable|disable|status]""$reset"
    echo "$yellow""  enable: Only allow devices with MAC addresses in maclist.csv""$reset"
    echo "$yellow""  disable: Allow any device to connect (SECURITY RISK)""$reset"
    echo "$yellow""  status: Show current MAC filtering status""$reset"
    echo ""
    echo "$blue""Current MAC filtering status:""$reset"
    for i in 0 1 2 3 4 5
        set status (uci -q get wireless.wifinet$i.macfilter)
        if test "$status" = "allow"
            echo "wifinet$i: $green""ENABLED (Secure)""$reset"
        else
            echo "wifinet$i: $red""DISABLED (Open)""$reset"
        end
    end
    exit 0
fi

# Commit changes and reload wireless configuration
uci commit wireless
wifi reload

echo "$blue""MAC filtering changes have been applied.""$reset"
' > "$BASE_DIR/manage_mac_filtering.sh"

    chmod +x "$BASE_DIR/manage_mac_filtering.sh"
    echo "$green""Created utility script $BASE_DIR/manage_mac_filtering.sh to manage MAC filtering.""$reset"
end

# DEBUG
# Add a check to ensure the network interface exists before assigning it
echo "$blue""Verifying network interfaces before assigning them...""$reset"
for i in 0 1 2 3 4 5
    set wifinet "wireless.wifinet$i"
    set network_name (uci get "$wifinet.network" 2>/dev/null)
    
    if test -n "$network_name"
        if not uci -q get "network.$network_name" > /dev/null
            echo "$red""ERROR: Network interface '$network_name' does not exist!""$reset"
            echo "$red""Wireless interface '$wifinet' will not be properly configured.""$reset"
        else
            echo "$green""Network interface '$network_name' exists, assigning it to '$wifinet'""$reset"
        end
    else
        echo "$yellow""WARNING: No network assigned to '$wifinet', skipping verification.""$reset"
    end
end
# DEBUG

# Note: UCI commits are handled in 98-commit.sh instead
echo "$green""Wireless configuration changes complete. Changes will be applied during final commit.""$reset"

# Final status message - simplified to just state the current status
echo "$green""Wireless configuration script completed successfully.""$reset"
echo "$green""MAC filtering is ENABLED. Only devices in the maclist.csv file can connect.""$reset"
