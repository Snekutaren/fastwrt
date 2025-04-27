#!/usr/bin/fish
# MAC filtering management script for FastWrt

# Source colors from profile directory or use defaults
set COLORS_FILES "$PROFILE_DIR/colors.fish" "$DEFAULTS_DIR/colors.fish" "$CONFIG_DIR/colors.fish" "$BASE_DIR/colors.fish" "$BASE_DIR/scripts/etc/uci-defaults/config/profiles/sne/colors.fish"
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
    set reset (echo -e "\033[0m")
end

if test "$1" = "enable"
    echo "$blue""Enabling MAC filtering...""$reset"
    for i in (seq 0 10)
        if uci -q get wireless.wifinet$i > /dev/null 2>&1
            uci set wireless.wifinet$i.macfilter="allow"
            echo "$green""Enabled MAC filtering for wifinet$i""$reset"
        end
    end
    echo "$green""MAC filtering enabled - only devices with allowed MAC addresses can connect""$reset"
elif test "$1" = "disable"
    echo "$red""Disabling MAC filtering...""$reset"
    echo "$red""WARNING: This will allow ANY device to connect to your networks!""$reset"
    echo "$yellow""Press Ctrl+C within 5 seconds to cancel...""$reset"
    sleep 5
    for i in (seq 0 10)
        if uci -q get wireless.wifinet$i > /dev/null 2>&1
            uci set wireless.wifinet$i.macfilter="disable"
            echo "$yellow""Disabled MAC filtering for wifinet$i""$reset"
        end
    end
    echo "$yellow""MAC filtering disabled - any device can now connect to your networks""$reset"
else
    echo "$blue""MAC Filtering Management Script""$reset"
    echo "$yellow""Usage: $0 [enable|disable|status]""$reset"
    echo "$yellow""  enable: Only allow devices with MAC addresses in maclist.csv""$reset"
    echo "$yellow""  disable: Allow any device to connect (SECURITY RISK)""$reset"
    echo "$yellow""  status: Show current MAC filtering status""$reset"
    echo ""
    
    if test "$1" = "status"
        echo "$blue""Current MAC filtering status:""$reset"
        set any_found 0
        for i in (seq 0 10)
            if uci -q get wireless.wifinet$i > /dev/null 2>&1
                set status (uci -q get wireless.wifinet$i.macfilter)
                set ssid (uci -q get wireless.wifinet$i.ssid)
                if test "$status" = "allow"
                    echo "wifinet$i ($ssid): $green""ENABLED (Secure)""$reset"
                else
                    echo "wifinet$i ($ssid): $red""DISABLED (Open)""$reset"
                end
                set any_found 1
            end
        end
        
        if test $any_found -eq 0
            echo "$yellow""No wireless interfaces found""$reset"
        end
    else
        echo "$blue""Current MAC filtering status:""$reset"
        set count_allow 0
        set count_disable 0
        set total 0
        
        for i in (seq 0 10)
            if uci -q get wireless.wifinet$i > /dev/null 2>&1
                set status (uci -q get wireless.wifinet$i.macfilter)
                if test "$status" = "allow"
                    set count_allow (math $count_allow + 1)
                else
                    set count_disable (math $count_disable + 1)
                end
                set total (math $total + 1)
            end
        end
        
        if test $count_allow -eq $total
            echo "$green""All $total interfaces have MAC filtering ENABLED""$reset"
        else if test $count_disable -eq $total
            echo "$red""All $total interfaces have MAC filtering DISABLED""$reset"
        else
            echo "$yellow""Mixed status: $count_allow enabled, $count_disable disabled""$reset"
            echo "$yellow""Run with 'status' for details""$reset"
        end
    end
    exit 0
fi

# Commit changes and reload wireless configuration
uci commit wireless
wifi reload

echo "$blue""MAC filtering changes have been applied.""$reset"
