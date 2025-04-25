#!/usr/bin/fish
# FastWrt configuration validation and summary - No commits, just reports changes

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Parse command line arguments
set brief_mode false
set validation_only false
set show_detailed false

for arg in $argv
    switch $arg
        case "--brief"
            set brief_mode true
        case "--validation-only"
            set validation_only true
        case "--show-detailed"
            set show_detailed true
    end
end

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Skip standard header if called with brief mode
if test "$brief_mode" = "false"
    # Make the summary script capable of handling both direct execution and being called by install.sh
    if set -q PRINT_SUMMARY_ONLY; and test "$PRINT_SUMMARY_ONLY" = "true"
        echo "$yellow""--- Configuration summary ---""$reset"
    else
        # Log the purpose of the script when run directly
        echo "$purple""Validating and summarizing configuration changes (NO COMMITS)...""$reset"
    end
end

# Define function to show summary of modified configurations
function show_modified_configs
    echo "$yellow""The following UCI configurations have been modified:""$reset"
    set modified_configs (uci changes | cut -d. -f1 | sort -u)
    
    # Check if there are any changes to summarize
    if test -z "$modified_configs"
        echo "$yellow""No UCI changes detected.""$reset"
        return 1
    end
    
    # Display each modified configuration
    for config in $modified_configs
        echo "- $config"
    end
    
    return 0
end

# Define function to generate detailed summary
function generate_summary
    set dryrun_mode $argv[1]
    
    # Output a concise summary of changes
    if test "$brief_mode" = "false"
        echo "$yellow""Configuration change summary:""$reset"
    end
    
    set total_changes (uci changes | wc -l)
    
    # Get counts by configuration type without directly displaying negative entries
    set modified_configs (uci changes | grep -v "^-" | cut -d. -f1 | sort -u)
    
    # Handle negative entries specially
    set negative_entries (uci changes | grep "^-" 2>/dev/null || echo "")
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
    
    # Count changes by type for a summarized view - ENHANCED FOR WIREGUARD
    set network_changes (uci changes network | grep -v -i "wireguard\|wg" | wc -l)
    set wireless_changes (uci changes wireless | wc -l)
    set firewall_changes (uci changes firewall | wc -l)
    set dhcp_changes (uci changes dhcp | wc -l)
    set system_changes (uci changes system | wc -l)
    set wireguard_changes (uci changes | grep -i "wireguard\|wg" | wc -l)
    set other_changes (uci changes | grep -v -e "network" -e "wireless" -e "firewall" -e "dhcp" -e "system" -e "wireguard" -e "wg" | wc -l)
    
    # Calculate comprehensive total to ensure accuracy
    set calculated_total (math $network_changes + $wireless_changes + $firewall_changes + $dhcp_changes + $system_changes + $wireguard_changes + $other_changes)
    
    # Show summary counts
    echo "$green""Network changes: ""$reset"$network_changes
    echo "$green""Wireless changes: ""$reset"$wireless_changes
    echo "$green""Firewall changes: ""$reset"$firewall_changes
    echo "$green""DHCP/DNS changes: ""$reset"$dhcp_changes
    echo "$green""WireGuard changes: ""$reset"$wireguard_changes
    echo "$green""System changes: ""$reset"$system_changes
    echo "$green""Other changes: ""$reset"$other_changes
    
    echo "$green""Total of $total_changes changes across ""$reset"(count $modified_configs + (count $negative_entries))"$green"" configuration files.""$reset"
    
    # Verify count accuracy - show warning if there's a discrepancy
    if test $calculated_total -ne $total_changes
        echo "$yellow""Warning: Calculated total ($calculated_total) differs from reported total ($total_changes)""$reset"
        echo "$yellow""This may indicate changes that aren't categorized properly""$reset"
    end
    
    # Show detailed changes in debug mode or if explicitly requested
    if test "$DEBUG" = "true"; or test "$show_detailed" = "true" 
        echo "$yellow""--- DETAILED UCI CHANGES ---""$reset"
        for config in $modified_configs
            echo "$blue""Changes in $config:""$reset"
            uci changes $config
            echo ""
        end
        
        # Special handling for WireGuard settings - ensure they're displayed
        # WireGuard settings are part of the network configuration but need special attention
        if contains "network" $modified_configs
            # Check specifically for WireGuard-related changes
            set wireguard_changes (uci changes network | grep -i "wireguard\|wg")
            if test -n "$wireguard_changes"
                echo "$blue""WireGuard-specific settings:""$reset"
                echo "$wireguard_changes"
                echo ""
            else
                # Also check if the wireguard interface exists but has no changes
                if uci -q get network.wireguard > /dev/null
                    echo "$blue""WireGuard interface exists but has no pending changes""$reset"
                    echo "Current settings:"
                    uci -q show network.wireguard
                    echo ""
                end
            end
            
            # Show WireGuard peers for a complete picture
            set wg_peers (uci show network | grep "=wireguard_peer" | cut -d'=' -f1)
            if test -n "$wg_peers"
                echo "$blue""WireGuard peer configurations:""$reset"
                for peer in $wg_peers
                    echo "Peer: $peer"
                    uci show $peer
                end
                echo ""
            end
        end
        
        echo "$yellow""--- END OF DETAILED UCI CHANGES ---""$reset"
        
        # Set a global flag that detailed summary has been shown
        set -g SUMMARY_DETAILED_SHOWN true
        # Create a marker file that install.sh can check
        touch /tmp/fastwrt_detailed_summary_shown
    end
    
    # Add appropriate message based on dry run mode
    if test "$dryrun_mode" = "true"; and test "$brief_mode" = "false"
        echo "$yellow""No changes will be applied (dry run mode).""$reset"
    else if test "$brief_mode" = "false"
        if set -q PRINT_SUMMARY_ONLY; and test "$PRINT_SUMMARY_ONLY" = "true"
            # When called from install.sh
            echo "$yellow""Changes will be committed or reverted by the main installation script.""$reset"
        else
            # When run directly
            echo "$yellow""NOTE: This script only validates and summarizes changes. All commits are handled by 01-install.sh.""$reset"
        end
    end
    
    # Return success
    return 0
end

# Main execution flow - much simpler linear structure
if test "$validation_only" = "true"
    echo "$blue""Running validation only mode...""$reset"
    # Skip summary generation entirely
else
    # Only try to show configs and generate summary if not in validation-only mode
    if show_modified_configs
        # Only generate summary if modified configs were found and displayed
        generate_summary "$DRY_RUN"
    end
end

# Validation functions always run regardless of mode
function validate_configs
    set has_errors false
    
    # Check for negative entries but handle them differently
    set negative_entries (uci changes | grep "^-" 2>/dev/null | sort -u)
    set negative_count (count $negative_entries)
    
    # Only report a count of removed entries in normal mode, no details needed
    if test $negative_count -gt 0
        if test "$DEBUG" != "true"
            echo "$blue""Found $negative_count configuration entries being replaced (normal during reconfiguration)""$reset"
        else
            # Count by type without using the test compound operator
            set dhcp_count 0
            set firewall_count 0
            set network_count 0
            set wireless_count 0
            
            # Count by type safely
            for entry in $negative_entries
                if string match -q "*dhcp*" -- $entry
                    set dhcp_count (math $dhcp_count + 1)
                else if string match -q "*firewall*" -- $entry
                    set firewall_count (math $firewall_count + 1)
                else if string match -q "*network*" -- $entry
                    set network_count (math $network_count + 1)
                else if string match -q "*wireless*" -- $entry
                    set wireless_count (math $wireless_count + 1)
                end
            end
            
            # Display counts only if they are greater than zero
            if test $dhcp_count -gt 0
                echo "$yellow""DHCP entries being removed: $dhcp_count""$reset"
            end
            if test $firewall_count -gt 0
                echo "$yellow""Firewall entries being removed: $firewall_count""$reset"
            end
            if test $network_count -gt 0
                echo "$yellow""Network entries being removed: $network_count""$reset"
            end
            if test $wireless_count -gt 0
                echo "$yellow""Wireless entries being removed: $wireless_count""$reset"
            end
            echo "$yellow""These are expected during reconfiguration and will be handled automatically""$reset"
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
    end
    
    # Return false if any errors were found
    test "$has_errors" = "false"
end

# Add a comprehensive validation function that can set the commit authorization
function validate_configuration
    set -l has_critical_errors false
    
    # Skip validation details in brief mode
    if test "$brief_mode" = "false"
        echo "$blue""Validating network interfaces...""$reset"
    end
    
    # Validate network interfaces
    for net in core guest iot meta nexus nodes
        if not uci -q get "network.$net" > /dev/null
            echo "$red""ERROR: Required network $net is missing!""$reset"
            set has_critical_errors true
        end
    end
    
    # Validate firewall zones
    if test "$brief_mode" = "false"
        echo "$blue""Validating firewall zones...""$reset"
    end
    
    for zone in core guest iot meta wan wireguard
        if not uci -q show firewall | grep -q "name='$zone'" > /dev/null
            echo "$red""ERROR: Required firewall zone $zone is missing!""$reset"
            set has_critical_errors true
        end
    end
    
    # Validate DHCP configuration
    if test "$brief_mode" = "false" 
        echo "$blue""Validating DHCP configuration...""$reset"
    end
    
    for net in core guest iot meta
        if not uci -q get "dhcp.$net" > /dev/null
            echo "$red""ERROR: Required DHCP pool for $net is missing!""$reset"
            set has_critical_errors true
        end
    end
    
    # Validate IP address conflicts
    set addresses
    set duplicates 0
    for net in (uci show network | grep "\.ipaddr=" | cut -d= -f1)
        set ip (uci get $net)
        for existing in $addresses
            if test "$existing[1]" = "$ip"
                set duplicates (math $duplicates + 1)
                echo "$red""ERROR: IP address $ip used in both $existing[2] and $net""$reset"
                set has_critical_errors true
            end
        end
        set -a addresses "$ip" "$net"
    end
    
    # Report if no duplicates were found
    if test $duplicates -eq 0; and test "$brief_mode" = "false"
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
            if test "$DEBUG" = "true"; and test "$brief_mode" = "false"
                echo "$yellow""Skipping validation of default zone $zone_name - will be replaced""$reset"
            end
            continue
        end
        
        # Special handling for wan_zone which may include wan6
        if test "$zone_name" = "wan"; or test "$zone" = "firewall.wan_zone"
            if test "$DEBUG" = "true"; and test "$brief_mode" = "false"
                echo "$yellow""WAN zone may include references to wan6 (normal if IPv6 is not configured)""$reset"
            end
            continue
        end
        
        for net in $networks
            # Skip 'lan', 'wan', 'wan6' network checks as these are defaults that will be replaced
            if test "$net" = "lan"; or test "$net" = "wan"; or test "$net" = "wan6"
                if test "$DEBUG" = "true"; and test "$brief_mode" = "false"
                    echo "$yellow""Ignoring reference to default network '$net' in zone '$zone_name'""$reset"
                end
                continue
            end
            
            if not uci -q get network.$net > /dev/null
                set firewall_errors (math $firewall_errors + 1)
                echo "$red""ERROR: Firewall zone $zone references non-existent network: $net""$reset"
                set has_critical_errors true
            end
        end
    end
    
    # Report firewall validation results
    if test $firewall_errors -eq 0; and test "$brief_mode" = "false"
        echo "$green""All firewall zone-to-network mappings validated successfully""$reset"
    else if test $firewall_errors -gt 0; and test "$brief_mode" = "false"
        echo "$red""Found $firewall_errors errors in firewall zone-to-network mappings""$reset"
    end
    
    # Return false if any errors were found
    test "$has_critical_errors" = "false"
end

# Call the validation function and set authorization token if successful
if validate_configuration
    set -gx COMMIT_AUTHORIZED true
    echo "$green""Commit authorization granted - configuration is valid""$reset"
else
    set -gx COMMIT_AUTHORIZED false
    echo "$red""Commit authorization DENIED - configuration has critical issues""$reset"
end

# Skip final message in brief mode
if test "$brief_mode" = "false"
    echo "$green""Configuration verification completed.""$reset"
end

exit 0