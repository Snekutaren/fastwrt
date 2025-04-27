#!/usr/bin/fish
# Helper script to verify MAC filtering configuration

# Source colors from profile directory or use defaults
set COLORS_FILES "$PROFILE_DIR/colors.fish" "$DEFAULTS_DIR/colors.fish" "$CONFIG_DIR/colors.fish" "$BASE_DIR/colors.fish"
for file_path in $COLORS_FILES
    if test -f "$file_path"
        source "$file_path"
        break
    end
end

# Fallback if colors not loaded
if not set -q green
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set purple (echo -e "\033[0;35m")
    set reset (echo -e "\033[0m")
end

echo "$purple""MAC Filtering Status Check""$reset"

# 1. Check MAC filtering mode for all wireless interfaces
set any_network_found 0
set interfaces_with_mac_filtering 0
set interfaces_without_mac_filtering 0
set interfaces_with_macs 0
set interfaces_without_macs 0

echo "$blue""Checking wireless interfaces...""$reset"
for i in (seq 0 10)
    if uci -q get "wireless.wifinet$i" > /dev/null
        set any_network_found 1
        set ssid (uci -q get "wireless.wifinet$i.ssid" || echo "Unknown")
        set macfilter (uci -q get "wireless.wifinet$i.macfilter" || echo "not set")
        set maclist_count (uci -q get "wireless.wifinet$i.maclist" 2>/dev/null | wc -l)
        
        echo -n "Interface wifinet$i ($ssid): "
        
        if test "$macfilter" = "allow" -o "$macfilter" = "deny"
            echo -n "$green""MAC filtering: $macfilter""$reset"
            set interfaces_with_mac_filtering (math $interfaces_with_mac_filtering + 1)
        else
            echo -n "$red""MAC filtering: $macfilter (disabled)""$reset"
            set interfaces_without_mac_filtering (math $interfaces_without_mac_filtering + 1)
        end
        
        if test $maclist_count -gt 0
            echo " - $green""$maclist_count MAC addresses""$reset"
            set interfaces_with_macs (math $interfaces_with_macs + 1)
        else
            echo " - $red""0 MAC addresses (empty list)""$reset"
            set interfaces_without_macs (math $interfaces_without_macs + 1)
        end
    end
end

if test $any_network_found -eq 0
    echo "$red""No wireless interfaces found!""$reset"
    exit 1
end

# 2. List MAC addresses registered in the system
echo "$blue"""\nMAC addresses registered in the system:""$reset"
set all_macs
for i in (seq 0 10)
    if uci -q get "wireless.wifinet$i" > /dev/null
        set maclist (uci -q get "wireless.wifinet$i.maclist" 2>/dev/null)
        for mac in $maclist
            if not contains "$mac" $all_macs
                set -a all_macs "$mac"
            end
        end
    end
end

if test (count $all_macs) -gt 0
    echo "$green""Found "(count $all_macs)" unique MAC addresses:""$reset"
    for mac in $all_macs
        echo "- $mac"
    end
else
    echo "$red""No MAC addresses found in any wireless interface!""$reset"
fi

# 3. Check MAC addresses in maclist.csv
echo "$blue"""\nComparing with maclist.csv entries:""$reset"

# Find the maclist.csv file
set MACLIST_FILES "$PROFILE_DIR/maclist.csv" "$CONFIG_DIR/maclist.csv" "$BASE_DIR/maclist.csv"
set MACLIST_PATH ""

for file_path in $MACLIST_FILES
    if test -f "$file_path"
        set MACLIST_PATH "$file_path"
        break
    end
end

if test -f "$MACLIST_PATH"
    set csv_macs
    set mac_count 0
    
    # Read MAC addresses from CSV
    while read -l line
        # Skip comment lines and empty lines
        if string match -q "#*" $line; or test -z (string trim "$line")
            continue
        end
        
        # Parse CSV line (format: mac,ip,name,network)
        set fields (string split "," $line)
        if test (count $fields) -ge 4
            set mac (string trim "$fields[1]")
            set name (string trim "$fields[3]")
            set -a csv_macs "$mac:$name"
            set mac_count (math $mac_count + 1)
        end
    end < "$MACLIST_PATH"
    
    echo "$green""Found $mac_count MAC addresses in maclist.csv""$reset"
    
    # Compare CSV MACs with registered MACs
    echo "$blue""Checking MAC registration status:""$reset"
    set registered 0
    set missing 0
    
    for entry in $csv_macs
        set parts (string split ":" $entry)
        set mac $parts[1]
        set name $parts[2]
        
        if contains "$mac" $all_macs
            echo "$green""✓ $mac ($name) is registered""$reset"
            set registered (math $registered + 1)
        else
            echo "$red""✗ $mac ($name) is NOT registered""$reset"
            set missing (math $missing + 1)
        end
    end
    
    echo "$blue"""\nSummary:""$reset"
    echo "Total MAC addresses in CSV: $mac_count"
    echo "Registered MAC addresses: $registered"
    echo "Missing MAC addresses: $missing"
    
    if test $missing -gt 0
        echo "$red""WARNING: $missing MAC addresses from maclist.csv are not registered!""$reset"
    else
        echo "$green""All MAC addresses from maclist.csv are properly registered.""$reset"
    fi
    
    # Check for unknown MACs (registered but not in CSV)
    set unknown_macs
    for mac in $all_macs
        set found 0
        for entry in $csv_macs
            set parts (string split ":" $entry)
            if test "$mac" = "$parts[1]"
                set found 1
                break
            end
        end
        
        if test $found -eq 0
            set -a unknown_macs $mac
        end
    end
    
    if test (count $unknown_macs) -gt 0
        echo "$yellow""Found "(count $unknown_macs)" MAC addresses registered but not in maclist.csv:""$reset"
        for mac in $unknown_macs
            echo "- $mac"
        end
    fi
else
    echo "$red""maclist.csv file not found!""$reset"
fi

# Provide summary and recommendations
echo "$blue"""\nSystem Status:""$reset"
echo "- Interfaces with MAC filtering enabled: $interfaces_with_mac_filtering"
echo "- Interfaces with MAC filtering disabled: $interfaces_without_mac_filtering"
echo "- Interfaces with MAC addresses: $interfaces_with_macs"
echo "- Interfaces with empty MAC lists: $interfaces_without_macs"

if test $interfaces_with_mac_filtering -gt 0 -a $interfaces_without_macs -gt 0
    echo "$red""WARNING: Some interfaces have MAC filtering enabled but NO MAC addresses registered!""$reset"
    echo "$red""This will prevent ALL devices from connecting!""$reset"
fi

echo "$blue"""\nRecommendations:""$reset"
if test $missing -gt 0
    echo "1. Run the configuration script again to register MAC addresses properly"
    echo "2. Check maclist.csv format for any errors"
    echo "3. Verify that the MAC addresses in maclist.csv are correctly formatted"
fi

if test $interfaces_without_macs -gt 0 -a $interfaces_with_mac_filtering -gt 0
    echo "If you're locked out, run: uci set wireless.wifinet0.macfilter=disable; uci commit wireless; wifi"
fi

echo "$green""MAC filtering check complete.""$reset"
