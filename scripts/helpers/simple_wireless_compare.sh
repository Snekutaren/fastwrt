#!/bin/sh
# Simple wireless comparison script using basic shell commands for maximum compatibility
# This script uses /bin/sh instead of fish for better compatibility across all OpenWrt installations

echo "===== Simple Wireless Configuration Analyzer ====="
echo "This script will help identify settings that might cause the 'Indoor Only Channel' error"
echo

echo "Extracting current wireless radio configuration..."
uci show wireless > /tmp/wireless_all.txt
grep "wifi-device" /tmp/wireless_all.txt > /tmp/radio_config.txt
grep "indoor\|dfs\|regulatory\|country\|htmode\|channel" /tmp/wireless_all.txt > /tmp/key_settings.txt

echo
echo "===== CURRENT WIRELESS RADIO SETTINGS ====="
cat /tmp/radio_config.txt

echo
echo "===== KEY SETTINGS THAT MAY AFFECT INDOOR CHANNEL ERROR ====="
cat /tmp/key_settings.txt

echo
echo "===== CHECKING FOR PROBLEMATIC SETTINGS ====="

# Check for indoor mode settings
if grep -q "indoor='1'" /tmp/key_settings.txt; then
    echo "Found indoor='1' setting which may be causing the validation error!"
    echo "Recommendation: Remove this setting with 'uci -q delete wireless.radioX.indoor'"
fi

# Check for DFS mode settings
if grep -q "dfs_" /tmp/key_settings.txt; then
    echo "Found DFS settings which may conflict with regulatory domain settings!"
    echo "Recommendation: Remove these settings with 'uci -q delete wireless.radioX.dfs_mode'"
fi

# Check for non-standard settings
if grep -q "legacy_rates\|noscan" /tmp/key_settings.txt; then
    echo "Found non-standard settings (legacy_rates/noscan) which may cause issues!"
    echo "Recommendation: Remove these with 'uci -q delete wireless.radioX.legacy_rates'"
fi

echo
echo "===== RECOMMENDED STANDARD SETTINGS ====="
echo "For 2.4GHz radio (radio0):"
echo "  Country: US"
echo "  Channel: 1"
echo "  HT Mode: HT20"
echo "  Cell Density: 0"
echo "  (No indoor/outdoor setting)"
echo
echo "For 5GHz radio (radio1):"
echo "  Country: US"
echo "  Channel: 36"
echo "  HT Mode: VHT80"
echo "  Cell Density: 0"
echo "  (No indoor/outdoor setting)"

echo
echo "===== COMMANDS TO APPLY STANDARD SETTINGS ====="
echo "# Reset to standard settings and remove all problematic parameters:"
echo "# For 2.4GHz"
echo "uci set wireless.radio0.channel='1'"
echo "uci set wireless.radio0.htmode='HT20'"
echo "uci set wireless.radio0.country='US'"
echo "uci set wireless.radio0.cell_density='0'"
echo "uci -q delete wireless.radio0.indoor"
echo "uci -q delete wireless.radio0.dfs_mode"
echo "uci -q delete wireless.radio0.legacy_rates"
echo "uci -q delete wireless.radio0.noscan"
echo
echo "# For 5GHz"
echo "uci set wireless.radio1.channel='36'"
echo "uci set wireless.radio1.htmode='VHT80'"
echo "uci set wireless.radio1.country='US'"
echo "uci set wireless.radio1.cell_density='0'"
echo "uci -q delete wireless.radio1.indoor"
echo "uci -q delete wireless.radio1.dfs_mode"
echo "uci -q delete wireless.radio1.legacy_rates"
echo "uci -q delete wireless.radio1.noscan"
echo
echo "# Apply settings"
echo "uci commit wireless"
echo "wifi reload"
echo
echo "After applying these changes, you should be able to create SSIDs in LuCI"