#!/usr/bin/fish
# FastWrt Runtime Status Checker

# Source colors definition
set SCRIPT_DIR (dirname (status filename))
set COLOR_FILE "$SCRIPT_DIR/../etc/uci-defaults/colors.fish"
if test -f "$COLOR_FILE" 
    source "$COLOR_FILE"
else
    # Fallback color definitions
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set purple (echo -e "\033[0;35m")
    set reset (echo -e "\033[0m")
end

echo "$purple""FastWrt Runtime Status Checker""$reset"
echo "$blue""Current time: ""$reset"(date)

# Check network interfaces
echo "$purple""Network Interface Status:""$reset"
ip -c a | grep -E 'eth|lan|wan|wlan|br-'

# Check bridge status
echo "$purple""Bridge Status:""$reset"
brctl show | grep -E 'lan|wan'

# Check wireless status
echo "$purple""Wireless Status:""$reset"
iwinfo | grep -E 'ESSID|Channel|Mode|Encryption'

# Check firewall status
echo "$purple""Firewall Status:""$reset"
if uci show firewall | grep -q '@zone'
    echo "$green""Firewall zones configured""$reset"
    uci show firewall | grep -E 'zone\[.*\].name' | sort
else
    echo "$red""Firewall zones not found""$reset"
end

# Check DHCP status
echo "$purple""DHCP Server Status:""$reset"
if test -f /tmp/dhcp.leases
    echo "$green""DHCP server is active with ""$reset"(cat /tmp/dhcp.leases | wc -l)"$green"" leases""$reset"
else
    echo "$red""DHCP lease file not found""$reset"
end

# Check DNS server status
echo "$purple""DNS Server Status:""$reset"
ps | grep dnsmasq | grep -v grep
if test $status -eq 0
    echo "$green""DNS server is running""$reset"
else
    echo "$red""DNS server is not running""$reset"
end

# Check SSH server status
echo "$purple""SSH Server Status:""$reset"
ps | grep dropbear | grep -v grep
if test $status -eq 0
    echo "$green""SSH server is running on port ""$reset"(uci get dropbear.@dropbear[0].Port 2>/dev/null || echo "unknown")
else
    echo "$red""SSH server is not running""$reset"
end

# Check pending changes
echo "$purple""Pending UCI Changes:""$reset"
set changes (uci changes)
if test (count $changes) -gt 0
    echo "$yellow""There are ""$reset"(count $changes)"$yellow"" pending changes:""$reset"
    
    # Look for invalid/problematic entries (with - prefix)
    set invalid_entries (uci changes | grep "^-" | sort -u)
    if test (count $invalid_entries) -gt 0
        echo "$red""WARNING: Found ""$reset"(count $invalid_entries)"$red"" problematic entries with '-' prefix:""$reset"
        for entry in $invalid_entries
            echo "$red""- $entry""$reset"
        end
        
        echo "$yellow""These entries might cause issues. Would you like to fix them? [y/N]""$reset"
        read -P '> ' fix_response
        
        if test "$fix_response" = "y" -o "$fix_response" = "Y"
            echo "$blue""Attempting to fix problematic entries...""$reset"
            for entry in $invalid_entries
                set section (echo $entry | cut -d. -f1 | sed 's/^-//')
                echo "$yellow""Fixing: $section by reverting changes""$reset"
                uci revert $section
                echo "$green""Reverted $section""$reset"
            end
            echo "$green""Fix completed. Please run uci commit to apply changes.""$reset"
        end
    end
    
    # Show changes by config type for better organization
    set config_types (uci changes | grep -v "^-" | cut -d. -f1 | sort -u)
    echo "$yellow""Changes grouped by configuration:""$reset"
    
    for config in $config_types
        echo "$blue""$config:""$reset"
        uci changes $config | grep -v "^-" | sort | awk '{print "  "$0}'
    end
else
    echo "$green""No pending UCI changes""$reset"
end

# Check for network interfaces that may be missing
echo "$purple""Network Interface Cross-Check:""$reset"
set defined_interfaces (uci show network | grep "=interface" | cut -d. -f2 | cut -d= -f1)
echo "$blue""Defined interfaces in UCI: ""$reset"(string join ", " $defined_interfaces)

# Check if firewall zones match network interfaces
echo "$purple""Firewall Zone to Network Interface Mapping:""$reset"
for zone in (uci show firewall | grep "\.name=" | cut -d. -f2 | cut -d= -f1)
    set zone_name (uci get firewall.$zone.name 2>/dev/null | tr -d "'")
    set zone_networks (uci get firewall.$zone.network 2>/dev/null | tr -d "'" | tr ' ' ',')
    
    echo "$blue""Zone: $zone_name → Networks: $zone_networks""$reset"
    
    # Validate that each network in firewall zone exists
    for net in (echo $zone_networks | tr ',' ' ')
        if not contains $net $defined_interfaces
            echo "$red""  ERROR: Network '$net' referenced in firewall zone '$zone_name' does not exist!""$reset"
        else
            echo "$green""  ✓ Network '$net' exists""$reset"
        end
    end
end

# Add a section for wireless configuration validation
echo "$purple""Wireless Configuration Validation:""$reset"
for iface in (uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1)
    set network (uci get wireless.$iface.network 2>/dev/null | tr -d "'")
    set ssid (uci get wireless.$iface.ssid 2>/dev/null | tr -d "'")
    
    echo "$blue""SSID: $ssid → Network: $network""$reset"
    
    # Check if network exists
    if not contains $network $defined_interfaces
        echo "$red""  ERROR: Network '$network' referenced by SSID '$ssid' does not exist!""$reset"
    else
        echo "$green""  ✓ Network '$network' exists""$reset"
    end
    
    # Check MAC filtering
    set macfilter (uci get wireless.$iface.macfilter 2>/dev/null | tr -d "'")
    if test "$macfilter" = "allow"
        set maclist_count (uci show wireless.$iface.maclist 2>/dev/null | wc -l)
        echo "$yellow""  MAC filtering enabled with $maclist_count allowed devices""$reset"
    else
        echo "$blue""  MAC filtering disabled""$reset"
    end
end

echo "$purple""Status check completed""$reset"
exit 0
