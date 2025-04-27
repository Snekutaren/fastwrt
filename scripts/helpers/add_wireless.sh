#!/usr/bin/fish
# Helper script to add new wireless networks (SSIDs) with proper network configurations
# This script helps create new SSIDs that work correctly with the VLAN setup

# Process command line arguments
if test (count $argv) -lt 3
    echo "Usage: add_wireless.sh <ssid_name> <password> <network> [radio] [encryption]"
    echo "  <ssid_name>: Name of the wireless network (SSID)"
    echo "  <password>: Password for the wireless network"
    echo "  <network>: Network to assign (core, guest, iot, meta, nexus, nodes)"
    echo "  [radio]: Radio to use (radio0=2.4GHz, radio1=5GHz, both=both radios) (default: both)"
    echo "  [encryption]: Encryption type (psk, psk2, sae, sae-mixed) (default: psk2)"
    exit 1
end

set ssid_name $argv[1]
set password $argv[2]
set network $argv[3]
set radio "both"
set encryption "psk2"

if test (count $argv) -gt 3
    set radio $argv[4]
end

if test (count $argv) -gt 4
    set encryption $argv[5]
end

# Validate network
set valid_networks core guest iot meta nexus nodes
set network (string lower $network)

if not contains $network $valid_networks
    echo "Error: Invalid network. Must be one of: core, guest, iot, meta, nexus, nodes"
    exit 1
end

# Validate radio
if test "$radio" != "radio0" -a "$radio" != "radio1" -a "$radio" != "both"
    echo "Error: Invalid radio. Must be radio0, radio1, or both"
    exit 1
end

# Validate encryption
set valid_encryption psk psk2 sae "sae-mixed"
if not contains $encryption $valid_encryption
    echo "Error: Invalid encryption. Must be one of: psk, psk2, sae, sae-mixed"
    exit 1
end

# Verify that network exists
if not uci -q get "network.$network" > /dev/null
    echo "Error: Network '$network' does not exist in UCI configuration."
    echo "Available networks:"
    uci show network | grep -E "^network\.[^\.]+\.device=" | cut -d. -f2
    exit 1
end

# Create a unique identifier for the new wireless interface
set datetime (date +%Y%m%d%H%M%S)
set random_suffix (head -c 4 /dev/urandom | hexdump -e '"%x"')
set wifi_id "wifinet_$datetime$random_suffix"

echo "Creating new wireless network:"
echo "  SSID: $ssid_name"
echo "  Network: $network"
echo "  Radio(s): $radio"
echo "  Encryption: $encryption"

# Function to add a wireless interface to a specific radio
function add_wireless_interface
    set radio_device $argv[1]
    
    echo "Adding wireless interface for $radio_device..."
    uci set "wireless.$wifi_id"='wifi-iface'
    uci set "wireless.$wifi_id.device"=$radio_device
    uci set "wireless.$wifi_id.mode"='ap'
    uci set "wireless.$wifi_id.ssid"="$ssid_name"
    uci set "wireless.$wifi_id.encryption"="$encryption"
    uci set "wireless.$wifi_id.key"="$password"
    uci set "wireless.$wifi_id.network"="$network"
    uci set "wireless.$wifi_id.macfilter"='disable'
end

# Add the wireless interface to the appropriate radio(s)
if test "$radio" = "radio0" -o "$radio" = "both"
    add_wireless_interface "radio0"
end

if test "$radio" = "radio1" -o "$radio" = "both"
    # For "both" mode, create a second interface with a different ID
    if test "$radio" = "both"
        set wifi_id2 "wifinet_${datetime}${random_suffix}_5g"
        set wifi_id $wifi_id2
    end
    
    add_wireless_interface "radio1"
end

# Commit the changes and reload wireless
echo "Committing changes..."
uci commit wireless

echo "Reloading wireless configuration..."
wifi reload

echo "New wireless network '$ssid_name' has been created successfully!"
echo "It is associated with the '$network' network."
echo 
echo "To connect: "
echo "  SSID: $ssid_name"
echo "  Password: $password"
echo
echo "The wireless network should now be visible in LuCI and to clients."