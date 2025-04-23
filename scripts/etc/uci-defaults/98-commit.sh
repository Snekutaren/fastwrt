#!/usr/bin/fish
# FastWrt pending changes summary - Report changes only, install.sh handles commits

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
echo "$purple""Generating summary of pending configuration changes...""$reset"

# Get a list of all modified UCI configurations
echo "$yellow""The following UCI configurations have been modified:""$reset"
set modified_configs (uci changes | cut -d. -f1 | sort -u)

# Check if there are any changes to summarize
if test -z "$modified_configs"
    echo "$yellow""No UCI changes detected.""$reset"
    exit 0
end

# Output a summary of changes for logging
echo "$yellow""Configuration change summary:""$reset"
set total_changes (uci changes | wc -l)
echo "$green""Total of $total_changes changes across ""$reset"(count $modified_configs)"$green"" configuration files.""$reset"

echo "$yellow""NOTE: All commits will be handled by the main install.sh script.""$reset"

# Create a summary file in /tmp for reference
if test "$DEBUG" = "true"
    set SUMMARY_FILE "/tmp/fastwrt_pending_changes.txt"
    echo "FastWrt Configuration Changes Summary" > $SUMMARY_FILE
    echo "Generated: "(date) >> $SUMMARY_FILE
    echo "------------------------------------" >> $SUMMARY_FILE
    
    for config in $modified_configs
        echo "Changes in $config:" >> $SUMMARY_FILE
        uci changes $config >> $SUMMARY_FILE
        echo "" >> $SUMMARY_FILE
    end
    
    echo "$blue""Detailed change summary saved to $SUMMARY_FILE""$reset"
end

# Function to check for potential conflicts or problems in config
function validate_configs
    set has_errors false
    
    # Check for problematic negative entries
    set negative_entries (uci changes | grep "^-" | sort -u)
    if test (count $negative_entries) -gt 0
        echo "$yellow""Warning: Found entries with '-' prefix that may cause issues:""$reset"
        for entry in $negative_entries
            echo "  $entry"
        end
        echo "$yellow""These are typically from old configs being deleted and can be ignored.""$reset"
    end
    
    # Check for wireless config issues - don't treat WRT names as unusual
    if string match -q "*wifi-iface*" -- (uci changes wireless 2>/dev/null)
        # Verify SSID values are set properly
        for i in (seq 0 5)
            set ssid (uci -q get wireless.wifinet$i.ssid)
            # Skip SSID warnings about WRT patterns - these are expected
            if test -z "$ssid"
                echo "$yellow""WARNING: Wireless interface wifinet$i missing SSID""$reset"
            else
                echo "$green""Wireless interface wifinet$i: SSID is $ssid""$reset"
            end
        end
    end
    
    # Check for duplicate IP addresses across networks
    set addresses
    for net in (uci show network | grep "\.ipaddr=" | cut -d= -f1)
        set ip (uci get $net)
        for existing in $addresses
            if test "$existing[1]" = "$ip"
                echo "$red""ERROR: IP address $ip used in both $existing[2] and $net""$reset"
                set has_errors true
            end
        end
        set -a addresses "$ip" "$net"
    end
    
    # Check firewall zones match network interfaces
    # Skip checking for 'lan' and 'wan' networks in default zones
    for zone in (uci show firewall | grep "\.network=" | cut -d= -f1)
        set zone_name (uci -q get firewall."$zone".name | tr -d "'")
        set networks (uci get $zone | tr "'" " " | tr -d "\"")
        
        # Skip validation of default zones that might reference removed interfaces
        if test "$zone_name" = "lan"; or test "$zone_name" = "wan"
            echo "$yellow""Skipping validation of default zone $zone_name - will be replaced""$reset"
            continue
        end
        
        for net in $networks
            # Skip 'lan', 'wan', 'wan6' network checks as these are defaults that will be replaced
            if test "$net" = "lan"; or test "$net" = "wan"; or test "$net" = "wan6"
                echo "$yellow""Ignoring reference to default network '$net' in zone '$zone_name'""$reset"
                continue
            end
        
            if not uci -q get network.$net > /dev/null
                echo "$red""ERROR: Firewall zone $zone references non-existent network: $net""$reset"
                set has_errors true
            end
        end
    end
    
    # Return false if any errors were found
    test "$has_errors" = "false"
end

# Run validation
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
# It does NOT handle commits (handled by 01-install.sh) OR post-setup tasks (handled by 99-first-boot.sh)
echo "$green""Configuration verification completed.""$reset"

exit 0
