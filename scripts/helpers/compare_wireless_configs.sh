#!/usr/bin/fish
# Script to compare wireless configurations between a clean OpenWrt build and FastWrt
# This helps identify differences that might be causing the "Indoor Only Channel" error

echo "===== Wireless Configuration Comparison Tool ====="
echo "This script will help identify differences between clean OpenWrt and FastWrt wireless configs"
echo

# Function to extract current wireless config
function extract_current_config
    echo "Extracting current wireless configuration..."
    
    # Save full config
    uci export wireless > /tmp/fastwrt_wireless.txt
    
    # Extract radio configs separately
    echo "# Radio Device Configuration" > /tmp/fastwrt_radios.txt
    uci show wireless | grep -E "wireless\.[^\.]+\.|\[radio" | sort >> /tmp/fastwrt_radios.txt
    
    # Extract interface configs separately
    echo "# Wireless Interface Configuration" > /tmp/fastwrt_interfaces.txt
    uci show wireless | grep -E "wifi-iface|\.ssid=|\.network=|\.encryption=|\.key=" | sort >> /tmp/fastwrt_interfaces.txt
    
    echo "Current configuration saved to /tmp/fastwrt_wireless.txt"
end

# Create reference configuration from default OpenWrt settings
function create_reference_config
    echo "Creating reference OpenWrt wireless configuration..."
    
    # Create temp dir
    mkdir -p /tmp/openwrt_ref
    cd /tmp/openwrt_ref
    
    # Create reference config with minimal settings - using echo statements instead of heredoc
    echo "config wifi-device 'radio0'" > wireless
    echo "	option type 'mac80211'" >> wireless
    echo "	option path 'platform/18000000.wmac'" >> wireless
    echo "	option channel '1'" >> wireless
    echo "	option band '2g'" >> wireless
    echo "	option htmode 'HT20'" >> wireless
    echo "	option cell_density '0'" >> wireless
    echo "	option country 'US'" >> wireless
    echo "" >> wireless
    echo "config wifi-device 'radio1'" >> wireless
    echo "	option type 'mac80211'" >> wireless
    echo "	option path 'pci0000:00/0000:00:01.0/0000:01:00.0'" >> wireless
    echo "	option channel '36'" >> wireless
    echo "	option band '5g'" >> wireless
    echo "	option htmode 'VHT80'" >> wireless
    echo "	option cell_density '0'" >> wireless
    echo "	option country 'US'" >> wireless
    echo "" >> wireless
    echo "config wifi-iface 'default_radio0'" >> wireless
    echo "	option device 'radio0'" >> wireless
    echo "	option network 'lan'" >> wireless
    echo "	option mode 'ap'" >> wireless
    echo "	option ssid 'OpenWrt'" >> wireless
    echo "	option encryption 'none'" >> wireless
    echo "" >> wireless
    echo "config wifi-iface 'default_radio1'" >> wireless
    echo "	option device 'radio1'" >> wireless
    echo "	option network 'lan'" >> wireless
    echo "	option mode 'ap'" >> wireless
    echo "	option ssid 'OpenWrt'" >> wireless
    echo "	option encryption 'none'" >> wireless

    # Convert to UCI format
    echo "# Standard OpenWrt Radio Device Configuration" > /tmp/openwrt_radios.txt
    cat wireless | grep -A 8 "wifi-device" | grep -v "^config" | sed 's/option /wireless.radio0./' | sort >> /tmp/openwrt_radios.txt
    
    echo "# Standard OpenWrt Wireless Interface Configuration" > /tmp/openwrt_interfaces.txt
    cat wireless | grep -A 6 "wifi-iface" | grep -v "^config" | sed 's/option /wireless.default_radio0./' | sort >> /tmp/openwrt_interfaces.txt
    
    echo "Reference configuration created at /tmp/openwrt_ref/wireless"
end

# Compare configurations to find differences
function compare_configs
    echo
    echo "===== COMPARING CONFIGURATIONS ====="
    
    # Find keys present in FastWrt but not in standard OpenWrt
    echo
    echo "Keys present in FastWrt but not in standard OpenWrt (radio devices):"
    grep -E "wireless\.[^\.]+\.[^=]+" /tmp/fastwrt_radios.txt | cut -d= -f1 | sort | uniq > /tmp/fastwrt_keys.txt
    grep -E "wireless\.[^\.]+\.[^=]+" /tmp/openwrt_radios.txt | cut -d= -f1 | sort | uniq > /tmp/openwrt_keys.txt
    grep -v -f /tmp/openwrt_keys.txt /tmp/fastwrt_keys.txt || echo "None"
    
    # Find keys present in standard OpenWrt but not in FastWrt
    echo
    echo "Keys present in standard OpenWrt but not in FastWrt (radio devices):"
    grep -v -f /tmp/fastwrt_keys.txt /tmp/openwrt_keys.txt || echo "None"
    
    # Compare common parameters
    echo
    echo "Different values for common parameters (radio devices):"
    for key in (cat /tmp/fastwrt_keys.txt /tmp/openwrt_keys.txt | sort | uniq)
        # Extract values, handling quotation - Fix: Changed sed syntax for fish compatibility
        set fastwrt_val (grep -E "^$key=" /tmp/fastwrt_radios.txt 2>/dev/null | cut -d= -f2- | sed "s/^'//;s/'$//g" || echo "")
        set openwrt_val (grep -E "^$key=" /tmp/openwrt_radios.txt 2>/dev/null | cut -d= -f2- | sed "s/^'//;s/'$//g" || echo "")
        
        # If both values exist and are different, show them
        if test -n "$fastwrt_val" -a -n "$openwrt_val" -a "$fastwrt_val" != "$openwrt_val"
            echo "$key: FastWrt='$fastwrt_val', OpenWrt='$openwrt_val'"
        end
    end
    
    # Additional check for any special settings related to indoor/outdoor
    echo
    echo "Indoor/outdoor related settings in FastWrt:"
    grep -E "indoor|outdoor|dfs|regulatory" /tmp/fastwrt_radios.txt || echo "None found"
end

# Check for any validation issues using a test config
function test_validation
    echo
    echo "===== TESTING VALIDATION ====="
    
    # Try to create a test network with minimal settings
    echo "Attempting to create a test wireless network with minimal settings..."
    
    # Generate a unique name
    set test_id (date +%s)
    
    # Create test interface with minimal settings
    echo "Creating test interface 'test_$test_id'..."
    uci set wireless.test_$test_id='wifi-iface'
    uci set wireless.test_$test_id.device='radio0'
    uci set wireless.test_$test_id.mode='ap'
    uci set wireless.test_$test_id.ssid="TestNet_$test_id"
    uci set wireless.test_$test_id.encryption='none'
    uci set wireless.test_$test_id.network='core'
    
    # Try to commit and check for errors
    echo "Attempting to commit changes..."
    if uci commit wireless 2>/tmp/test_error.txt
        echo "SUCCESS: Test network created with minimal settings"
        
        # Clean up
        echo "Removing test network..."
        uci delete wireless.test_$test_id
        uci commit wireless
    else
        echo "FAILURE: Error creating test network"
        echo "Error message:"
        cat /tmp/test_error.txt
    end
end

# Main execution
extract_current_config
create_reference_config
compare_configs
test_validation

echo
echo "===== RECOMMENDED CONFIGURATION ====="
echo "Based on standard OpenWrt, your wireless configuration should include these settings:"
echo

for radio in radio0 radio1
    echo "For $radio:"
    echo "  wireless.$radio.country='US'              # Standard regulatory domain"
    echo "  wireless.$radio.cell_density='0'          # Default cell density"
    
    if test "$radio" = "radio0"
        echo "  wireless.$radio.channel='1'               # Safe 2.4GHz channel"
        echo "  wireless.$radio.htmode='HT20'             # Conservative mode for 2.4GHz"
    else
        echo "  wireless.$radio.channel='36'              # Safe indoor 5GHz channel"
        echo "  wireless.$radio.htmode='VHT80'            # Standard mode for 5GHz"
    end
    
    echo "  # Remove any non-standard settings like 'indoor', 'dfs_mode', etc."
    echo
end

echo
echo "To apply these recommendations, you can use the following commands:"
echo
echo "# For 2.4GHz radio (radio0)"
echo "uci set wireless.radio0.country='US'"
echo "uci set wireless.radio0.cell_density='0'"
echo "uci set wireless.radio0.channel='1'"
echo "uci set wireless.radio0.htmode='HT20'"
echo "uci -q delete wireless.radio0.indoor"
echo "uci -q delete wireless.radio0.dfs_mode"
echo "uci -q delete wireless.radio0.legacy_rates"
echo "uci -q delete wireless.radio0.noscan"
echo
echo "# For 5GHz radio (radio1)"
echo "uci set wireless.radio1.country='US'"
echo "uci set wireless.radio1.cell_density='0'"
echo "uci set wireless.radio1.channel='36'"
echo "uci set wireless.radio1.htmode='VHT80'"
echo "uci -q delete wireless.radio1.indoor"
echo "uci -q delete wireless.radio1.dfs_mode"
echo "uci -q delete wireless.radio1.legacy_rates"
echo "uci -q delete wireless.radio1.noscan"
echo
echo "# Commit and reload"
echo "uci commit wireless"
echo "wifi reload"