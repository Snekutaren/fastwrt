#!/usr/bin/fish
# Script to reset wireless radio configurations to standard OpenWrt settings
# This should resolve the "Indoor Only Channel Selected" error in LuCI
# This does NOT modify your wifi interfaces (SSIDs) - only the radio device settings

echo "===== Resetting Wireless Radio Configuration to OpenWrt Standards ====="
echo "This script will modify radio settings only, not your wireless networks"
echo

# Backup current configuration
echo "Creating backup of current wireless configuration..."
uci export wireless > /tmp/wireless_backup_$(date +%Y%m%d%H%M%S).txt
echo "Backup saved to /tmp/wireless_backup_*.txt"

# Reset radio0 (2.4GHz) to standard settings
echo "Resetting radio0 (2.4GHz) to standard settings..."

# First, save the essential settings we want to keep
set type_radio0 (uci -q get wireless.radio0.type)
set path_radio0 (uci -q get wireless.radio0.path)
set disabled_radio0 (uci -q get wireless.radio0.disabled)

# Remove all current settings by recreating the section
uci -q delete wireless.radio0
uci set wireless.radio0='wifi-device'

# Restore essential settings
if test -n "$type_radio0"
    uci set wireless.radio0.type="$type_radio0"
end
if test -n "$path_radio0"
    uci set wireless.radio0.path="$path_radio0"
end
if test -n "$disabled_radio0"
    uci set wireless.radio0.disabled="$disabled_radio0"
else
    # Default to enabled
    uci set wireless.radio0.disabled='0'
end

# Apply standard settings for 2.4GHz
uci set wireless.radio0.channel='1'
uci set wireless.radio0.band='2g'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.country='US'
uci set wireless.radio0.cell_density='0'

# Reset radio1 (5GHz) to standard settings
echo "Resetting radio1 (5GHz) to standard settings..."

# First, save the essential settings we want to keep
set type_radio1 (uci -q get wireless.radio1.type)
set path_radio1 (uci -q get wireless.radio1.path)
set disabled_radio1 (uci -q get wireless.radio1.disabled)

# Remove all current settings by recreating the section
uci -q delete wireless.radio1
uci set wireless.radio1='wifi-device'

# Restore essential settings
if test -n "$type_radio1"
    uci set wireless.radio1.type="$type_radio1"
end
if test -n "$path_radio1"
    uci set wireless.radio1.path="$path_radio1"
end
if test -n "$disabled_radio1"
    uci set wireless.radio1.disabled="$disabled_radio1"
else
    # Default to enabled
    uci set wireless.radio1.disabled='0'
end

# Apply standard settings for 5GHz
uci set wireless.radio1.channel='36'
uci set wireless.radio1.band='5g'
uci set wireless.radio1.htmode='VHT80'
uci set wireless.radio1.country='US'
uci set wireless.radio1.cell_density='0'

# Commit changes
echo "Committing changes..."
uci commit wireless

# Reload wireless
echo "Reloading wireless configuration..."
wifi reload

echo
echo "===== Wireless configuration has been reset to OpenWrt standards ====="
echo "You should now be able to create new wireless networks in LuCI"
echo "Your existing wireless networks (SSIDs) have been preserved"
echo
echo "If you still encounter issues, please try rebooting your router"
echo "or run the command: /etc/init.d/uhttpd restart"