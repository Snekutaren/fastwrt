#!/usr/bin/fish
# FastWrt Wireless Association Display Tool
# Shows which devices are connected to which wireless networks

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m") 
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt Wireless Association Display Tool""$reset"
echo "$blue""Showing current wireless associations...""$reset"

# Function to get device details from MAC address
function get_device_details
    set mac $argv[1]
    
    # Try to get name from DHCP static leases
    set name ""
    set ip ""
    
    # Look through all DHCP host configurations
    set host_sections (uci show dhcp | grep "=host$" | cut -d'=' -f1)
    for section in $host_sections
        set host_mac (uci -q get "$section.mac")
        if string match -q -i "$mac" "$host_mac"
            set name (uci -q get "$section.name")
            set ip (uci -q get "$section.ip")
            break
        end
    end
    
    # If we couldn't find the name in static leases, check DHCP leases file
    if test -z "$name"; or test -z "$ip"
        # Parse DHCP leases file
        if test -f /tmp/dhcp.leases
            set lease_info (cat /tmp/dhcp.leases | grep -i "$mac")
            if test -n "$lease_info"
                # Format: lease_time MAC IP hostname *
                set lease_parts (string split " " "$lease_info")
                if test (count $lease_parts) -ge 4
                    set ip $lease_parts[3]
                    set name $lease_parts[4]
                end
            end
        end
    end
    
    # If still no name, use MAC as name
    if test -z "$name"
        set name "unknown"
    end
    
    # If still no IP, mark as unknown
    if test -z "$ip"
        set ip "unknown"
    end
    
    echo "$name|$ip"
end

# Find all wireless interfaces
set wireless_interfaces (ls -1 /sys/class/net/ | grep wlan)

if test (count $wireless_interfaces) -eq 0
    echo "$red""No wireless interfaces found!""$reset"
    exit 1
end

echo "$green""Found "(count $wireless_interfaces)" wireless interfaces""$reset"

# Track total associations
set total_associations 0

# For each wireless interface
for iface in $wireless_interfaces
    # Get SSID for this interface
    set ssid (iwinfo $iface info 2>/dev/null | grep ESSID | cut -d'"' -f2)
    
    # If no SSID, try to find from UCI config
    if test -z "$ssid"
        # Find the corresponding UCI section
        set device_path (readlink -f /sys/class/net/$iface/device 2>/dev/null)
        if test -n "$device_path"
            set device_name (basename "$device_path")
            # Try to find matching radio in UCI
            set radio_section (uci show wireless | grep "$device_name" | head -1 | cut -d'=' -f1 | cut -d'.' -f1-2)
            if test -n "$radio_section"
                set ssid (uci -q get $radio_section.ssid)
            end
        end
    end
    
    # If still no SSID, use interface name
    if test -z "$ssid"
        set ssid "Unknown ($iface)"
    end
    
    echo "$yellow""Interface: $iface - SSID: $ssid""$reset"
    
    # Get associated clients
    set clients (iwinfo $iface assoclist 2>/dev/null | grep -o -E '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
    
    # Count clients
    set client_count (count $clients)
    set total_associations (math $total_associations + $client_count)
    
    if test $client_count -eq 0
        echo "  $blue""No associated clients""$reset"
    else
        echo "  $green""$client_count associated clients:""$reset"
        
        # For each client
        for mac in $clients
            # Get signal strength
            set signal (iwinfo $iface assoclist 2>/dev/null | grep -i "$mac" | grep -o -E 'Signal: -[0-9]+ dBm' | cut -d' ' -f2)
            
            # Get device details (name and IP)
            set details (get_device_details "$mac")
            set name (string split "|" "$details")[1]
            set ip (string split "|" "$details")[2]
            
            # Format and show the info
            echo "  - $mac ($name, $ip) Signal: $signal"
        end
    end
    echo ""
end

# Summary
echo "$green""Total wireless associations: $total_associations""$reset"
echo "$green""You can use 'extract-maclist.fish' to create a maclist.csv with SSID information""$reset"
