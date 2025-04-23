#!/usr/bin/fish
# FastWrt configuration validation and summary - No commits, just reports changes

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the purpose of the script
echo "$purple""Validating and summarizing configuration changes (NO COMMITS)...""$reset"

# Get a list of all modified UCI configurations - but show them differently based on mode
echo "$yellow""The following UCI configurations have been modified:""$reset"
set modified_configs (uci changes | cut -d. -f1 | sort -u)

# Check if there are any changes to summarize
if test -z "$modified_configs"
    echo "$yellow""No UCI changes detected.""$reset"
    exit 0
end

# Output a concise summary of changes
echo "$yellow""Configuration change summary:""$reset"
set total_changes (uci changes | wc -l)

# Get counts by configuration type without directly displaying negative entries
# This avoids "Entry not found" errors
set modified_configs (uci changes | cut -d. -f1 | grep -v "^-" | sort -u)

# Handle negative entries specially
set negative_entries (uci changes | grep "^-" | cut -d. -f1 | sort -u)
set dhcp_neg_count 0
set firewall_neg_count 0
set network_neg_count 0
set wireless_neg_count 0

# Count negative entries more safely without using echo + grep which causes the error
for entry in $negative_entries
    if string match -q "*dhcp*" -- $entry
        set dhcp_neg_count (math $dhcp_neg_count + 1)
    else if string match -q "*firewall*" -- $entry
        set firewall_neg_count (math $firewall_neg_count + 1)
    else if string match -q "*network*" -- $entry
        set network_neg_count (math $network_neg_count + 1)
    else if string match -q "*wireless*" -- $entry
        set wireless_neg_count (math $wireless_neg_count + 1)
    end
end

# Display the counts safely by checking each count individually
if test $dhcp_neg_count -gt 0
    echo "$blue""- Removed DHCP entries: ""$reset"$dhcp_neg_count
end
if test $firewall_neg_count -gt 0
    echo "$blue""- Removed Firewall entries: ""$reset"$firewall_neg_count
end
if test $network_neg_count -gt 0
    echo "$blue""- Removed Network entries: ""$reset"$network_neg_count
end
if test $wireless_neg_count -gt 0
    echo "$blue""- Removed Wireless entries: ""$reset"$wireless_neg_count
end

# In regular mode, just show counts for added/changed entries
for config in $modified_configs
    set config_changes (uci changes $config | wc -l)
    echo "$blue""- $config: ""$reset"$config_changes" changes"
end

echo "$green""Total of $total_changes changes across ""$reset"(count $modified_configs + (count $negative_entries))"$green"" configuration files.""$reset"
echo "$yellow""NOTE: This script only validates and summarizes changes. All commits are handled by 01-install.sh.""$reset"

# Create a summary file in /tmp for reference - only in debug mode
if test "$DEBUG" = "true"
    set SUMMARY_FILE "/tmp/fastwrt_pending_changes.txt"
    echo "FastWrt Configuration Changes Summary" > $SUMMARY_FILE
    echo "Generated: "(date) >> $SUMMARY_FILE
    echo "------------------------------------" >> $SUMMARY_FILE
    
    # Only in debug mode show the full list of changes per config
    echo "$blue""Detailed UCI changes (only shown in debug mode):""$reset"
    for config in $modified_configs
        echo "$yellow""Changes in $config:""$reset"
        uci changes $config
        echo "" 
        
        # Also save to summary file
        echo "Changes in $config:" >> $SUMMARY_FILE
        uci changes $config >> $SUMMARY_FILE
        echo "" >> $SUMMARY_FILE
    end
    
    echo "$blue""Detailed change summary saved to $SUMMARY_FILE""$reset"
end

# Function to check for potential conflicts or problems in config
function validate_configs
    set has_errors false
    
    # Check for negative entries but handle them differently
    set negative_entries (uci changes | grep "^-" 2>/dev/null | sort -u)
    set negative_count (count $negative_entries)
    
    # Only report a count of removed entries in normal mode, no details needed
    if test $negative_count -gt 0
        if test "$DEBUG" != "true"
            # Just show total count in normal mode
            echo "$blue""Found $negative_count configuration entries being replaced (normal during reconfiguration)""$reset"
        else
            # In debug mode, show full details in a more manageable format
            echo "$yellow""Found negative entries by category (configurations being replaced):""$reset"
            
            # Get counts without attempting to show entries - avoids "Entry not found" errors
            set dhcp_count (echo $negative_entries | grep -c "^-dhcp" 2>/dev/null || echo 0)
            set firewall_count (echo $negative_entries | grep -c "^-firewall" 2>/dev/null || echo 0)
            set network_count (echo $negative_entries | grep -c "^-network" 2>/dev/null || echo 0)
            set wireless_count (echo $negative_entries | grep -c "^-wireless" 2>/dev/null || echo 0)
            
            # Show the counts by category
            test $dhcp_count -gt 0 && echo "$yellow""DHCP entries being removed: $dhcp_count""$reset"
            test $firewall_count -gt 0 && echo "$yellow""Firewall entries being removed: $firewall_count""$reset" 
            test $network_count -gt 0 && echo "$yellow""Network entries being removed: $network_count""$reset"
            test $wireless_count -gt 0 && echo "$yellow""Wireless entries being removed: $wireless_count""$reset"
            
            echo "$yellow""These are expected during reconfiguration and will be handled automatically.""$reset"
        end
    end
    
    # Check for wireless config issues - don't treat WRT names as unusual
    if string match -q "*wifi-iface*" -- (uci changes wireless 2>/dev/null)
        # Verify SSID values are set properly
        set ssid_missing 0
        set ssid_ok 0
        
        for i in (seq 0 5)
            set ssid (uci -q get wireless.wifinet$i.ssid)
            # Skip SSID warnings about WRT patterns - these are expected
            if test -z "$ssid"
                set ssid_missing (math $ssid_missing + 1)
                if test "$DEBUG" = "true"
                    echo "$yellow""WARNING: Wireless interface wifinet$i missing SSID""$reset"
                end
            else
                set ssid_ok (math $ssid_ok + 1)
                if test "$DEBUG" = "true"
                    echo "$green""Wireless interface wifinet$i: SSID is $ssid""$reset"
                end
            end
        end
        
        # Summary output for non-debug mode
        if test $ssid_missing -gt 0
            echo "$yellow""Found $ssid_missing wireless interfaces with missing SSIDs""$reset"
        end
        if test $ssid_ok -gt 0
            echo "$green""Verified $ssid_ok wireless interfaces with valid SSIDs""$reset"
        end
    end
    
    # Check for duplicate IP addresses across networks
    set addresses
    set duplicates 0
    for net in (uci show network | grep "\.ipaddr=" | cut -d= -f1)
        set ip (uci get $net)
        for existing in $addresses
            if test "$existing[1]" = "$ip"
                set duplicates (math $duplicates + 1)
                echo "$red""ERROR: IP address $ip used in both $existing[2] and $net""$reset"
                set has_errors true
            end
        end
        set -a addresses "$ip" "$net"
    end
    
    # Report if no duplicates were found
    if test $duplicates -eq 0
        echo "$green""No duplicate IP addresses detected across networks""$reset"
    end
    
    # Check firewall zones match network interfaces with cleaner output
    set firewall_errors 0
    set firewall_zones_checked 0
    
    # Skip checking for 'lan' and 'wan' networks in default zones
    for zone in (uci show firewall | grep "\.network=" | cut -d= -f1)
        set zone_name (uci -q get firewall."$zone".name | tr -d "'")
        set networks (uci get $zone | tr "'" " " | tr -d "\"")
        set firewall_zones_checked (math $firewall_zones_checked + 1)
        
        # Skip validation of default zones that might reference removed interfaces
        if test "$zone_name" = "lan"; or test "$zone_name" = "wan"
            if test "$DEBUG" = "true"
                echo "$yellow""Skipping validation of default zone $zone_name - will be replaced""$reset"
            end
            continue
        end
        
        # Special handling for wan_zone which may include wan6
        if test "$zone_name" = "wan"; or test "$zone" = "firewall.wan_zone"
            if test "$DEBUG" = "true"
                echo "$yellow""WAN zone may include references to wan6 (normal if IPv6 is not configured)""$reset"
            end
            continue
        end
        
        for net in $networks
            # Skip 'lan', 'wan', 'wan6' network checks as these are defaults that will be replaced
            if test "$net" = "lan"; or test "$net" = "wan"; or test "$net" = "wan6"
                if test "$DEBUG" = "true"
                    echo "$yellow""Ignoring reference to default network '$net' in zone '$zone_name'""$reset"
                end
                continue
            end
            
            if not uci -q get network.$net > /dev/null
                set firewall_errors (math $firewall_errors + 1)
                echo "$red""ERROR: Firewall zone $zone references non-existent network: $net""$reset"
                set has_errors true
            end
        end
    end
    
    # Report firewall validation results
    if test $firewall_errors -eq 0
        echo "$green""All firewall zone-to-network mappings validated successfully""$reset"
    else
        echo "$red""Found $firewall_errors errors in firewall zone-to-network mappings""$reset"
    end
    
    # Return false if any errors were found
    test "$has_errors" = "false"
end

# Run validation with cleaner output
echo "$yellow""Running configuration validation checks...""$reset"
if validate_configs
    echo "$green""All validation checks passed!""$reset"
else
    echo "$red""Some validation checks failed. Review warnings/errors above.""$reset"
    # Only exit with error for critical issues in non-dry-run mode
    if test "$DRY_RUN" != "true" 
        # Check for truly critical errors that should abort
        set critical_errors (uci changes | grep -E "network\.(core|guest|iot|meta)\.device=" | wc -l)
        if test $critical_errors -gt 0
            echo "$red""Critical network configuration errors detected!""$reset"
            exit 1
        end
    end
end

# Note: This script only validates and reports changes
# It does NOT handle commits (handled by 01-install.sh)
echo "$green""Configuration verification completed.""$reset"

exit 0