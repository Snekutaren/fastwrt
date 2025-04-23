#!/usr/bin/fish
# FastWrt utility script to update maclist.csv with newly connected devices
# Version 1.0

set MACLIST_PATH "$BASE_DIR/maclist.csv"
set TMP_DEVICES "/tmp/connected_devices.tmp"
set TMP_KNOWN "/tmp/known_devices.tmp"
set TMP_NEW "/tmp/new_devices.tmp"

echo "=== FastWrt MAC Updater Tool ==="
echo "This tool helps you update your maclist.csv with newly connected devices."
echo "Current time: "(date)

# Check if maclist exists and create if not
if not test -f "$MACLIST_PATH"
    echo "### This file contains a list of MAC addresses and their corresponding IP addresses and device names." > "$MACLIST_PATH"
    echo "### The format is as follows: " >> "$MACLIST_PATH"
    echo "# MAC_ADDRESS,IP_ADDRESS,DEVICE_NAME,NETWORK" >> "$MACLIST_PATH"
    echo "Created new maclist.csv file"
end

# Extract currently known MAC addresses from maclist.csv
echo "Extracting known devices from maclist.csv..."
grep -v "^#" "$MACLIST_PATH" | cut -d, -f1 > "$TMP_KNOWN"
echo "Found "(wc -l < "$TMP_KNOWN")" known devices."

# Get currently connected wireless clients
echo "Fetching currently connected wireless devices..."
iwinfo | grep -E "^[0-9a-fA-F:]{17}" | awk '{print $1}' > "$TMP_DEVICES"
echo "Found "(wc -l < "$TMP_DEVICES")" connected wireless devices."

# Find new devices that are not in maclist.csv
echo "Identifying new devices..."
sort "$TMP_DEVICES" "$TMP_KNOWN" "$TMP_KNOWN" | uniq -u > "$TMP_NEW"
set new_count (wc -l < "$TMP_NEW")
echo "Found $new_count new devices."

if test $new_count -eq 0
    echo "No new devices found. Your maclist.csv is up to date."
else
    echo "=== New Devices ==="
    echo "MAC Address         IP Address      Network Interface"
    echo "---------------------------------------------------"
    
    # Process each new device
    cat "$TMP_NEW" | while read -l mac
        # Get IP and interface information for this MAC
        set ip_info (grep -i $mac /proc/net/arp | awk '{print $1}')
        
        if test -z "$ip_info"
            set ip_info "Unknown"
        end
        
        # Get the wireless interface this MAC is connected to
        set wifi_info (iw dev | grep -B 5 -i $mac | grep "Interface" | awk '{print $2}')
        
        if test -z "$wifi_info"
            set wifi_info "Unknown"
        end
        
        # Get the network this interface belongs to
        set network "unknown"
        if string match -q "*0*" "$wifi_info"
            set network "iot"
        else if string match -q "*1*" "$wifi_info"; or string match -q "*2*" "$wifi_info"
            set network "guest"
        else if string match -q "*3*" "$wifi_info"; or string match -q "*4*" "$wifi_info"
            set network "core"
        else if string match -q "*5*" "$wifi_info"
            set network "meta"
        end
        
        # Print device info
        printf "%-20s %-15s %s\n" $mac $ip_info $network
        
        # Ask for device name
        echo -n "Enter device name for $mac (or press ENTER to skip): "
        read -l device_name
        
        if test -n "$device_name"
            # Add to maclist.csv
            echo "$mac,$ip_info,$device_name,$network" >> "$MACLIST_PATH"
            echo "Added $device_name to maclist.csv"
        else
            echo "Skipped device $mac"
        end
    end
    
    echo "=== Summary ==="
    echo "Updated maclist.csv with new devices."
    echo "You can review and edit the file at $MACLIST_PATH"
    echo "To enable MAC filtering after adding all devices, run the enable_mac_filtering.sh script"
end

# Clean up
rm -f "$TMP_DEVICES" "$TMP_KNOWN" "$TMP_NEW"
echo "Operation completed."