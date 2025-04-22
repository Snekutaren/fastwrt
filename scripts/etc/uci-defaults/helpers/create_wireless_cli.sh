#!/usr/bin/fish
# Command line utility to create wireless networks directly via UCI
# This bypasses LuCI's validation and can be used if LuCI's interface fails

function show_usage
    echo "Usage: create_wireless_cli.sh <ssid> <password> <network> [radio] [encryption]"
    echo
    echo "Create a new wireless network from the command line, bypassing LuCI"
    echo
    echo "Parameters:"
    echo "  <ssid>       Name of the wireless network (SSID)"
    echo "  <password>   Password for the wireless network (min 8 characters)"
    echo "  <network>    Network to assign (core, guest, iot, meta, etc.)"
    echo "  [radio]      Radio to use: radio0 (2.4GHz), radio1 (5GHz), or both (default)"
    echo "  [encryption] Encryption: none, psk, psk2, sae, sae-mixed (default: psk2)"
    echo
    echo "Example:"
    echo "  create_wireless_cli.sh MyWiFi MyPassword core both psk2"
end

# Check for minimum arguments
if test (count $argv) -lt 3
    show_usage
    exit 1
end

# Parse arguments
set ssid $argv[1]
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

# Validate network exists
if not uci -q get network.$network > /dev/null
    echo "Error: Network '$network' does not exist."
    echo "Available networks:"
    uci show network | grep -E "^network\.[^\.]+='interface'" | cut -d. -f2 | cut -d= -f1
    exit 1
end

# Validate radio
if test "$radio" != "radio0" -a "$radio" != "radio1" -a "$radio" != "both"
    echo "Error: Invalid radio. Must be radio0, radio1, or both"
    exit 1
end

# Validate encryption
if test "$encryption" != "none" -a "$encryption" != "psk" -a "$encryption" != "psk2" -a "$encryption" != "sae" -a "$encryption" != "sae-mixed"
    echo "Error: Invalid encryption. Must be none, psk, psk2, sae, or sae-mixed"
    exit 1
end

# Additional validation for security
if test "$encryption" != "none" -a (string length $password) -lt 8
    echo "Error: Password must be at least 8 characters for encryption: $encryption"
    exit 1
end

echo "Creating wireless network with the following settings:"
echo "  SSID: $ssid"
echo "  Network: $network"
echo "  Radio(s): $radio"
echo "  Encryption: $encryption"

# Create timestamp-based identifier for the interface
set timestamp (date +%s)
set random (head -c 8 /dev/urandom | md5sum | head -c 6)
set wifi_id "wifi_${timestamp}_${random}"

# Function to add a wireless interface for a specific radio
function add_wifi_interface
    set radio_id $argv[1]
    set wifi_name $argv[2]
    
    echo "Adding interface $wifi_name on $radio_id..."
    
    # Create the wireless interface
    uci set wireless.$wifi_name='wifi-iface'
    uci set wireless.$wifi_name.device=$radio_id
    uci set wireless.$wifi_name.mode='ap'
    uci set wireless.$wifi_name.ssid="$ssid"
    uci set wireless.$wifi_name.network=$network
    
    # Handle encryption settings
    if test "$encryption" = "none"
        uci set wireless.$wifi_name.encryption='none'
    else
        uci set wireless.$wifi_name.encryption="$encryption"
        uci set wireless.$wifi_name.key="$password"
    end
    
    # Default to open MAC filtering
    uci set wireless.$wifi_name.macfilter='disable'
    
    echo "Interface $wifi_name configured successfully on $radio_id"
end

# Create interfaces for selected radios
if test "$radio" = "radio0" -o "$radio" = "both"
    add_wifi_interface "radio0" $wifi_id
end

if test "$radio" = "radio1" -o "$radio" = "both"
    if test "$radio" = "both"
        # For both radios, create a separate ID for the 5GHz network
        set wifi_id_5g "${wifi_id}_5g"
        add_wifi_interface "radio1" $wifi_id_5g
    else
        add_wifi_interface "radio1" $wifi_id
    end
end

# Save changes
echo "Committing changes..."
uci commit wireless

# Apply changes
echo "Applying wireless configuration..."
wifi reload

echo
echo "===== Wireless network created successfully! ====="
echo "SSID: $ssid"
if test "$encryption" != "none"
    echo "Password: $password"
end
echo "The network should now be broadcasting."
echo

# Show new wireless configuration
echo "Current wireless interfaces:"
uci show wireless | grep -E "wifi-iface|ssid"