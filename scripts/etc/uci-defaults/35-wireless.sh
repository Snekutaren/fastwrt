#!/usr/bin/fish
# FastWrt wireless configuration script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
print_info "Current working directory: "(pwd)

# Log the purpose of the script
print_start "Starting wireless configuration script..."

# Load passphrases from file (check multiple locations in order)
set PASSPHRASE_FILES "$PROFILE_DIR/wifi.fish" "$DEFAULTS_DIR/wifi.fish" "$CONFIG_DIR/wifi.fish" "$BASE_DIR/wifi.fish"
set PASSPHRASE_PATH ""

for file_path in $PASSPHRASE_FILES
    if test -f "$file_path"
        set PASSPHRASE_PATH "$file_path"
        source "$file_path"
        echo "$green""Loaded passphrases from $PASSPHRASE_PATH""$reset"
        break
    end
end

if test -z "$PASSPHRASE_PATH"
    echo "$red""ERROR: Fish-compatible passphrases file not found! Please create a 'wifi.fish' file in one of these locations:""$reset"
    for path in $PASSPHRASE_FILES
        echo "$red""- $path""$reset"
    end
    exit 1
end

# FIX: Display SSIDs correctly from table-driven configuration
echo "$blue""Configuring wireless networks with SSIDs:""$reset"
if set -q WIFI_NETWORKS
    # Extract and display SSIDs from the table-driven configuration
    for network in $WIFI_NETWORKS
        set parts (string split "|" -- "$network")
        if test (count $parts) -ge 2
            echo "$blue""- $parts[2]""$reset"  # SSID is in position 2 of the table
        end
    end
else
    # Fallback to old-style variables if they exist
    if set -q SSID_OPENWRT
        echo "$blue""- $SSID_OPENWRT""$reset"
    end
    if set -q SSID_CLOSEDWRT
        echo "$blue""- $SSID_CLOSEDWRT""$reset"
    end
    if set -q SSID_IOTWRT
        echo "$blue""- $SSID_IOTWRT""$reset"
    end
    if set -q SSID_METAWRT
        echo "$blue""- $SSID_METAWRT""$reset"
    end
    
    # If none of the expected SSIDs were found, show error
    if not set -q SSID_OPENWRT; and not set -q SSID_CLOSEDWRT; and not set -q SSID_IOTWRT; and not set -q SSID_METAWRT
        echo "$yellow""WARNING: No wireless SSIDs found in configuration""$reset"
    end
end

# Add debugging statements to log variable values
if test "$DEBUG" = "true"
    echo "$yellow""DEBUG: WIFI_NETWORKS table content:""$reset"
    for network in $WIFI_NETWORKS
        echo "$yellow""$network""$reset"
    end
end

# Configure radio devices from the table-driven configuration
echo "$blue""Configuring radio devices from table...""$reset"
for radio_config in $WIFI_RADIOS
    # Parse radio configuration
    set parts (string split "|" -- "$radio_config")
    set radio_id $parts[1]
    set band $parts[2]
    set channel $parts[3]
    set htmode $parts[4]
    set indoor $parts[5]
    set cell_density $parts[6]
    
    echo "$blue""Configuring radio$radio_id ($band)...""$reset"
    uci set wireless.radio$radio_id='wifi-device'
    uci set wireless.radio$radio_id.channel="$channel"
    uci set wireless.radio$radio_id.band="$band"
    uci set wireless.radio$radio_id.htmode="$htmode"
    uci set wireless.radio$radio_id.disabled='0'
    uci set wireless.radio$radio_id.country="$WIFI_COUNTRY"
    uci set wireless.radio$radio_id.indoor="$indoor"
    uci set wireless.radio$radio_id.cell_density="$cell_density"
    echo "$green""$band radio configured.""$reset"
end

# Clear existing interfaces
set wifi_iface_count 0
echo "$blue""Clearing existing wireless configuration...""$reset"
while uci -q delete wireless.@wifi-iface[0] > /dev/null
  set wifi_iface_count (math $wifi_iface_count + 1)
  if test "$DEBUG" = "true"
    echo "$yellow""Deleted wireless.@wifi-iface[0]""$reset"
  end
end
echo "$green""Cleared $wifi_iface_count wireless interface entries""$reset"

# Configure wireless interfaces from the table-driven configuration
echo "$blue""Configuring wireless interfaces from table...""$reset"
set interface_counter 0

for network in $WIFI_NETWORKS
    # Parse network configuration
    set parts (string split "|" -- "$network")
    set net_id $parts[1]
    set ssid $parts[2]
    set passphrase $parts[3]
    set network_name $parts[4]
    set bands (string split "," -- "$parts[5]")
    set encryption $parts[6]
    
    # Create interface for each band
    for band in $bands
        # Select the appropriate radio for this band
        set radio_id 0
        if test "$band" = "5g"
            set radio_id 1
        end
        
        echo "$blue""Creating $ssid on $band band (radio$radio_id)...""$reset"
        set wifinet "wifinet$interface_counter"
        
        uci set wireless.$wifinet='wifi-iface'
        uci set wireless.$wifinet.device="radio$radio_id"
        uci set wireless.$wifinet.mode='ap'
        uci set wireless.$wifinet.ssid="$ssid"
        uci set wireless.$wifinet.key="$passphrase"
        uci set wireless.$wifinet.encryption="$encryption"
        uci set wireless.$wifinet.network="$network_name"
        
        # Initialize macfilter to 'disable' by default
        uci set wireless.$wifinet.macfilter='disable'
        
        echo "$green""$ssid network created with $encryption encryption on $band band""$reset"
        set interface_counter (math $interface_counter + 1)
    end
end

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

# Update the MAC filtering section to use the global setting
echo "$blue""Configuring MAC filtering to mode: $WIFI_MAC_FILTERING...""$reset"
for i in (seq 0 (math $interface_counter - 1))
    # Initially set MAC filtering to disabled - will be enabled later if MAC addresses are available
    uci set wireless.wifinet$i.macfilter='disable'
end

# Apply MAC addresses from maclist.csv if available
# Test both that the variable exists AND that it has elements
if set -q MAC_ADDRESSES; and test (count $MAC_ADDRESSES) -gt 0
    echo "$blue""Adding "(count $MAC_ADDRESSES)" MAC addresses to wireless interfaces...""$reset"
    
    # Track which networks have had MAC addresses added and counts for verification
    set mac_count_by_network
    for i in (seq 0 (math $interface_counter - 1))
        set mac_count_by_network[$i] 0
    end
    
    # Process each MAC address entry
    for mac_entry in $MAC_ADDRESSES
        # Parse MAC entry (format: mac:device_name:network)
        set mac_parts (string split ":" -- "$mac_entry")
        
        # Validate that we have all parts to prevent errors
        if test (count $mac_parts) -lt 3
            echo "$yellow""Invalid MAC entry format: $mac_entry - skipping""$reset"
            continue
        end
        
        set mac_addr "$mac_parts[1]"
        set device_name "$mac_parts[2]"
        set network_name "$mac_parts[3]"
        
        # Validate MAC address to prevent errors
        if not string match -q -r '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$' "$mac_addr"
            echo "$yellow""Invalid MAC address format: $mac_addr - skipping""$reset"
            continue
        end
        
        # Add MAC to appropriate wireless interfaces based on network
        for i in (seq 0 (math $interface_counter - 1))
            set wifinet "wireless.wifinet$i"
            set wifi_network (uci -q get "$wifinet.network" 2>/dev/null)
            
            # Skip if we couldn't get the network
            if test -z "$wifi_network"
                continue
            end
            
            # Either add to specific network or add to all networks if it's a core device
            if test "$wifi_network" = "$network_name"; or test "$network_name" = "core"
                echo "$blue""Adding MAC $mac_addr ($device_name) to $wifinet ($wifi_network)""$reset"
                
                # First check if this MAC is already in the list to maintain idempotency
                set existing_macs (uci -q get "$wifinet.maclist" 2>/dev/null)
                if string match -q "*$mac_addr*" "$existing_macs"
                    echo "$yellow""MAC $mac_addr already in list for $wifinet - skipping""$reset"
                else
                    uci add_list "$wifinet.maclist=$mac_addr"
                    set mac_count_by_network[$i] (math $mac_count_by_network[$i] + 1)
                    echo "$green""Added MAC $mac_addr to $wifinet""$reset"
                end
            end
        end
    end
    
    # Calculate total MACs added
    set total_mac_count 0
    for i in (seq 0 (math $interface_counter - 1))
        set total_mac_count (math $total_mac_count + $mac_count_by_network[$i])
    end
    
    echo "$green""Added a total of $total_mac_count MAC address entries to wireless interfaces""$reset"
    
    # Now enable MAC filtering if we have addresses and it's requested
    if test "$WIFI_MAC_FILTERING" = "allow"; or test "$WIFI_MAC_FILTERING" = "deny"
        # Verify each interface has MAC addresses before enabling filtering
        for i in (seq 0 (math $interface_counter - 1))
            set wifinet "wireless.wifinet$i"
            
            # Get MAC list count for this interface
            set mac_list_count $mac_count_by_network[$i]
            
            if test "$WIFI_MAC_FILTERING" = "allow"; and test $mac_list_count -eq 0
                # Safety feature: don't enable allow mode with no MACs - would lock everyone out
                echo "$yellow""Warning: Not enabling 'allow' filtering for $wifinet - no MAC addresses added""$reset"
            else
                # Safe to enable filtering
                uci set wireless.wifinet$i.macfilter="$WIFI_MAC_FILTERING"
                echo "$green""Enabled $WIFI_MAC_FILTERING filtering for $wifinet with $mac_list_count MAC addresses""$reset"
            end
        end
    else
        echo "$green""MAC filtering mode is set to '$WIFI_MAC_FILTERING' - no need to add MAC addresses""$reset"
    end
else
    echo "$yellow""No MAC addresses available for wireless filtering""$reset"
    
    # Verify that MAC filtering is properly disabled in this case
    if test "$WIFI_MAC_FILTERING" = "allow"
        echo "$yellow""WARNING: MAC filtering set to 'allow' but no MAC addresses found.""$reset"
        echo "$yellow""Disabled MAC filtering to prevent lockout.""$reset"
    end
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
echo "$green""MAC filtering is $WIFI_MAC_FILTERING. Only devices in the maclist.csv file can connect when set to 'allow'.""$reset"
