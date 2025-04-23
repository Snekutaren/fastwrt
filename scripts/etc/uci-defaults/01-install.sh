#!/usr/bin/fish
# FastWrt Installation Script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Start
echo "$blue""FastWrt Configuration Running from: ""$reset"(cd (dirname (status filename)) && pwd)
echo "$blue""Current time: ""$reset"(date)

# Default configuration
set DEBUG_MODE false
set DRY_RUN false
set ABORT_ON_ERROR true  # Flag to control error handling behavior

# Parse command line arguments
for arg in $argv
    switch $arg
        case "--debug"
            set DEBUG_MODE true
            echo "$yellow""Debug mode enabled""$reset"
            set -gx DEBUG true
        case "--dry-run"
            set DRY_RUN true
            echo "$yellow""Dry run mode enabled - no changes will be committed""$reset"
            set -gx DRY_RUN true
        case "--continue-on-error"
            set ABORT_ON_ERROR false
            echo "$yellow""Continue on error mode enabled - script will attempt to continue after errors""$reset"
    end
end

# Set BASE_DIR more robustly
set SCRIPT_PATH (status filename)
if string match -q "/*" "$SCRIPT_PATH"
    # Absolute path
    set BASE_DIR (dirname "$SCRIPT_PATH")
else
    # Relative path, use pwd
    set BASE_DIR (pwd)
end
set -gx BASE_DIR "$BASE_DIR"

# Make log directory in a writable location
set LOG_DIR "/tmp/fastwrt_logs"
mkdir -p "$LOG_DIR"
set LOG_FILE "$LOG_DIR/install_"(date +%Y%m%d_%H%M%S)".log"
echo "$blue""Logging installation process to $LOG_FILE""$reset"

# Check for root privileges
if test (id -u) -ne 0
    echo "$red""Please run as root""$reset"
    exit 1
end

set CURRENT_SCRIPT (realpath (status filename))

# Define script dependencies - which scripts must complete before others can run
# Format: script_name:dependency1,dependency2,...
set -l script_dependencies
set -a script_dependencies "40-dhcp.sh:30-network.sh"
set -a script_dependencies "50-firewall.sh:30-network.sh,40-dhcp.sh"
set -a script_dependencies "60-wireless.sh:30-network.sh,50-firewall.sh"

# Keep track of script success/failure
set -l completed_scripts
set -l failed_scripts

# Create env script in /tmp which is always writable
set FISH_ENV_SCRIPT "/tmp/fastwrt_env.fish"
begin
    echo '#!/usr/bin/fish'
    echo ''
    echo '# Set environment variables for the configuration'
    echo "set -gx BASE_DIR \"$BASE_DIR\""
    echo ''
    echo '# Pass through dry run mode and debug flags if set'
    echo 'if test "$DRY_RUN" = "true"'
    echo '  set -gx DRY_RUN true'
    echo '  echo "Fish environment: DRY RUN mode enabled"'
    echo 'else'
    echo '  set -gx DRY_RUN false'
    echo 'end'
    echo ''
    echo 'if test "$DEBUG" = "true"'
    echo '  set -gx DEBUG true'
    echo 'else'
    echo '  set -gx DEBUG false'
    echo 'end'
    echo ''
    echo '# Default configuration values'
    echo 'set -gx WIREGUARD_IP "10.255.0.1"'
    echo 'set -gx CORE_POLICY_IN "ACCEPT"'
    echo 'set -gx CORE_POLICY_OUT "ACCEPT"'
    echo 'set -gx CORE_POLICY_FORWARD "REJECT"'
    echo 'set -gx OTHER_ZONES_POLICY_IN "DROP"'
    echo 'set -gx OTHER_ZONES_POLICY_OUT "ACCEPT"'  # Keep as ACCEPT
    echo 'set -gx IOT_META_POLICY_OUT "DROP"'       # New policy for IoT and Meta
    echo 'set -gx OTHER_ZONES_POLICY_FORWARD "REJECT"'
    echo 'set -gx WAN_POLICY_IN "DROP"'
    echo 'set -gx WAN_POLICY_OUT "ACCEPT"'
    echo 'set -gx WAN_POLICY_FORWARD "DROP"'
    echo ''
    echo '# Option to enable WAN6'
    echo 'set -gx ENABLE_WAN6 false'
    echo ''
    echo '# Option to enable MAC filtering'
    echo 'set -gx ENABLE_MAC_FILTERING false'
    echo ''
    echo '# SSIDs'
    echo 'set -gx SSID_CLOSEDWRT "ClosedWrt"'
    echo 'set -gx SSID_OPENWRT "OpenWrt"'
    echo 'set -gx SSID_METAWRT "MetaWrt"'
    echo 'set -gx SSID_IOTWRT "IoTWrt"'
    echo ''
    echo '# Print environment variables only once'
    echo 'if status --is-interactive; and not set -q ENVIRONMENT_PRINTED'
    echo '  set -gx ENVIRONMENT_PRINTED 1'
    echo '  echo "Configuration environment set up."'
    echo '  echo "BASE_DIR: $BASE_DIR"'
    echo '  echo "DRY_RUN: $DRY_RUN"'
    echo '  echo "DEBUG: $DEBUG"'
    echo '  echo "Core policies: $CORE_POLICY_IN/$CORE_POLICY_OUT/$CORE_POLICY_FORWARD"'
    echo '  echo "WAN policies: $WAN_POLICY_IN/$WAN_POLICY_OUT/$WAN_POLICY_FORWARD"'
    echo '  echo "ENABLE_WAN6: $ENABLE_WAN6"'
    echo '  echo "ENABLE_MAC_FILTERING: $ENABLE_MAC_FILTERING"'
    echo '  echo "SSIDs: $SSID_OPENWRT, $SSID_CLOSEDWRT, $SSID_METAWRT, $SSID_IOTWRT"'
    echo 'end'
end > $FISH_ENV_SCRIPT

# Passphrase and MAC list
set USE_PREGENERATED_PASSPHRASES true
set PASSPHRASE_LENGTH 32
echo "$blue""Using pregenerated passphrases: $USE_PREGENERATED_PASSPHRASES""$reset"
echo "$blue""Passphrase length: $PASSPHRASE_LENGTH""$reset"

set MACLIST_PATH "$BASE_DIR/maclist.csv"
if test -f "$MACLIST_PATH"
    echo "$green""Maclist file found at: $MACLIST_PATH""$reset"
else
    echo "$red""Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist.csv' file.""$reset"
    exit 1
end

if test "$USE_PREGENERATED_PASSPHRASES" = "true"
    echo "$blue""Checking for fish-compatible passphrases file in $BASE_DIR...""$reset"
    if test -f "$BASE_DIR/passphrases.fish"
        echo "$green""Fish-compatible passphrases file found at: $BASE_DIR/passphrases.fish""$reset"
    else
        echo "$red""Error: Fish-compatible passphrases file not found in $BASE_DIR. Please create a 'passphrases.fish' file.""$reset"
        exit 1
    end
else
    echo "# Generating random passphrases" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_OPENWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_CLOSEDWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_IOTWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_METAWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
end

if test "$DEBUG" = "true"
    echo "$blue""Generated fish environment script contents:""$reset"
    cat "$FISH_ENV_SCRIPT"
end

# Function to check if dependencies are met for a script
function dependencies_met
    set -l script_name $argv[1]
    
    # Find dependencies for this script
    for dep_entry in $script_dependencies
        set -l parts (string split ":" -- "$dep_entry")
        
        # If this is not about our script, continue
        if test "$parts[1]" != "$script_name"
            continue
        end
        
        # If no dependencies (unlikely given the structure), return true
        if test (count $parts) -lt 2
            return 0
        end
        
        # Check each dependency
        set -l deps (string split "," -- "$parts[2]")
        for dep in $deps
            # If dependency not in completed scripts, return false
            if not contains "$dep" $completed_scripts
                echo "$red""Script $script_name depends on $dep which has not completed successfully""$reset"
                return 1
            end
        end
    end
    
    # No dependencies or all dependencies met
    return 0
end

# Execute all .sh scripts in the directory, skipping itself
set SCRIPTS_DIR "$BASE_DIR"
if test ! -d "$SCRIPTS_DIR"
    echo "$red""Scripts directory not found: $SCRIPTS_DIR""$reset"
    exit 1
end

echo "$blue""Scripts directory: $SCRIPTS_DIR""$reset"
echo "$blue""Scripts to execute:""$reset"
ls -l "$SCRIPTS_DIR"/*.sh | tee -a "$LOG_FILE"

echo "$purple""Executing configuration scripts with fish shell...""$reset"

# Get a list of scripts sorted by name (numeric prefix)
set scripts_to_run (find "$SCRIPTS_DIR" -maxdepth 1 -name "[0-9]*.sh" | sort)

# Track overall success
set overall_success true

for script in $scripts_to_run
    # Skip the main script
    if test (realpath "$script") = "$CURRENT_SCRIPT"
        echo "$yellow""Skipping self: $script""$reset"
        continue
    end
    
    set script_basename (basename "$script")
    
    # Check if dependencies are met
    if not dependencies_met "$script_basename"
        echo "$red""Skipping $script_basename due to unmet dependencies""$reset"
        set -a failed_scripts "$script_basename"
        
        if test "$ABORT_ON_ERROR" = "true"
            set overall_success false
            echo "$red""Aborting due to dependency failures""$reset"
            break
        end
        continue
    end
    
    echo "$blue""Running $script""$reset"
    if fish -C "source $FISH_ENV_SCRIPT" "$script" 2>&1 | tee -a "$LOG_FILE"
        echo "$green""Script $script completed successfully""$reset"
        set -a completed_scripts "$script_basename"
    else
        set exit_status $status
        echo "$red""ERROR: Script $script failed with exit code $exit_status""$reset"
        echo "$red""IMPORTANT: When scripts fail with errors like 'missing networks', this indicates a fundamental configuration issue.""$reset"
        echo "$red""DO NOT try to work around with fallback networks - fix the root cause in 30-network.sh instead.""$reset"
        set -a failed_scripts "$script_basename"
        
        if test "$ABORT_ON_ERROR" = "true"
            set overall_success false
            echo "$red""Aborting due to script failure""$reset"
            break
        end
    end
end

echo "$blue""All scripts executed.""$reset"

# If any scripts failed or we're in dry-run mode
if test "$overall_success" = "false"; or test "$DRY_RUN" = "true"
    echo "$yellow""--- Script execution summary ---""$reset"
    echo "$green""Completed scripts (""$reset"(count $completed_scripts)"$green""): ""$reset"
    for script in $completed_scripts
        echo "  - $script"
    end
    
    if test (count $failed_scripts) -gt 0
        echo "$red""Failed scripts (""$reset"(count $failed_scripts)"$red""): ""$reset"
        for script in $failed_scripts
            echo "  - $script"
        end
    end
    
    if test "$DRY_RUN" = "false"; and test "$overall_success" = "false"
        echo "$red""Configuration failed. Check the log for errors: $LOG_FILE""$reset"
        echo "$red""Reverting all changes due to failures...""$reset"
        
        # Only revert configs that actually exist (not negative entries)
        set configs_to_revert (uci changes | grep -v "^-" | cut -d. -f1 | sort -u)
        for cfg in $configs_to_revert
            echo "Reverting $cfg..."
            uci revert $cfg
        end
        
        echo "$yellow""All changes have been reverted. No changes were committed.""$reset"
        exit 1
    end
end

# Dry run mode - show only a concise summary of changes
if test "$DRY_RUN" = "true"
    echo "$yellow""--- DRY RUN: Configuration summary ---""$reset"
    
    # Get count of modified UCI configurations - safely handling negative entries
    set modified_configs (uci changes | grep -v "^-" | cut -d. -f1 | sort -u)
    set total_changes (uci changes | wc -l)
    
    # Handle negative entries safely - avoid using echo pipe to grep which causes errors
    set negative_entries (uci changes | grep "^-" | cut -d. -f1 | sort -u 2>/dev/null)
    set dhcp_neg_count 0
    set firewall_neg_count 0
    set network_neg_count 0
    set wireless_neg_count 0
    
    # Count negative entries by looping through them directly
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
    
    # Only show the detailed changes in debug mode
    if test "$DEBUG" = "true"
        echo "$yellow""--- DETAILED UCI CHANGES (debug mode) ---""$reset"
        # Only attempt to show positive entries that won't cause errors
        for config in $modified_configs
            echo "$blue""Changes in $config:""$reset"
            uci changes $config
            echo ""
        end
        
        # Show the negative entry counts
        echo "$yellow""Entries being removed:""$reset"
        test $dhcp_neg_count -gt 0 && echo "- DHCP entries: $dhcp_neg_count"
        test $firewall_neg_count -gt 0 && echo "- Firewall entries: $firewall_neg_count" 
        test $network_neg_count -gt 0 && echo "- Network entries: $network_neg_count"
        test $wireless_neg_count -gt 0 && echo "- Wireless entries: $wireless_neg_count"
        echo "$yellow""--- END OF DETAILED UCI CHANGES ---""$reset"
    else
        # In regular mode, just show counts by configuration type
        echo "$blue""Configuration changes detected:""$reset"
        # Show negative entry counts properly
        if test $dhcp_neg_count -gt 0
            echo "- Removed DHCP entries: $dhcp_neg_count"
        end
        if test $firewall_neg_count -gt 0
            echo "- Removed Firewall entries: $firewall_neg_count"
        end
        if test $network_neg_count -gt 0
            echo "- Removed Network entries: $network_neg_count"
        end
        if test $wireless_neg_count -gt 0
            echo "- Removed Wireless entries: $wireless_neg_count"
        end
        
        # Show positive entry counts
        for config in $modified_configs
            set config_changes (uci changes $config | wc -l)
            echo "- $config: $config_changes changes"
        end
    end
    
    echo "$green""Total: $total_changes changes across ""$reset"(count $modified_configs + (count $negative_entries))"$green"" configuration files.""$reset"
    echo "$yellow""No changes were applied (dry run mode).""$reset"
    exit 0
end

# If dry-run is enabled, show UCI changes instead of committing them
if test "$DRY_RUN" = "true"
    echo "$purple""--- DRY RUN: Displaying detected UCI configuration changes ---""$reset"
    
    # Fix for negative UCI entries - identify and handle them first
    set negative_entries (uci changes | grep "^-" | sort -u)
    if test (count $negative_entries) -gt 0
        echo "$yellow""Warning: Found entries with '-' prefix that may cause issues:""$reset"
        # Only in debug mode do we show the full list
        if test "$DEBUG" = "true"
            for entry in $negative_entries
                echo "  $entry"
            end
        else
            # Group by category and just show counts
            set dhcp_count (echo $negative_entries | grep -c "^-dhcp")
            set firewall_count (echo $negative_entries | grep -c "^-firewall")
            set network_count (echo $negative_entries | grep -c "^-network")
            set wireless_count (echo $negative_entries | grep -c "^-wireless")
            
            echo "$blue""Configuration entries being replaced:""$reset"
            test $dhcp_count -gt 0 && echo "  - DHCP: $dhcp_count entries"
            test $firewall_count -gt 0 && echo "  - Firewall: $firewall_count entries"
            test $network_count -gt 0 && echo "  - Network: $network_count entries"
            test $wireless_count -gt 0 && echo "  - Wireless: $wireless_count entries"
            echo "$blue""These are normal during reconfiguration.""$reset"
        end
    end
    
    # Display changes by configuration sections with privacy filtering
    set modified_configs (uci changes | grep -v "^-" | cut -d. -f1 | sort -u)
    if test (count $modified_configs) -eq 0
        echo "$yellow""No UCI changes detected.""$reset"
    else
        # Only show detailed changes in debug mode
        if test "$DEBUG" = "true"
            for cfg in $modified_configs
                echo "$yellow""Changes in: $cfg""$reset"
                uci changes $cfg | tee -a "$LOG_FILE"
            end
        else
            # In non-debug mode, summarize by category and hide sensitive information
            echo "$yellow""Configuration changes summary:""$reset"
            for cfg in $modified_configs
                set changes_count (uci changes $cfg | wc -l)
                echo "$blue""- $cfg: $changes_count changes""$reset"
                
                # For security-sensitive configs, show special messages
                if test "$cfg" = "network"; and uci changes $cfg | grep -q wireguard
                    echo "$yellow""  Note: WireGuard settings included (keys masked in non-debug mode)""$reset"
                end
                if test "$cfg" = "wireless"
                    echo "$yellow""  Note: Wireless settings included (passphrases masked in non-debug mode)""$reset"
                end
            end
        end
    end
    echo "$purple""--- END OF UCI CHANGES ---""$reset"
    
    echo "$yellow""Reverting all changes due to dry run mode...""$reset" 
    # Only revert configs that actually exist (not negative entries)
    set configs_to_revert (uci changes | grep -v "^-" | cut -d. -f1 | sort -u)
    
    # Properly formatted for loop with end statement
    for cfg in $configs_to_revert
        echo "Reverting $cfg..."
        uci revert $cfg
    end

    echo "$green""Dry run completed. All changes have been reverted.""$reset"
    rm -f "$FISH_ENV_SCRIPT"    
    exit 0
else
    # Finalize configuration if not a dry run
    echo "$purple""Committing UCI changes...""$reset"
    uci commit
    
    echo "$purple""Restarting services in proper order...""$reset"
    # Network first, then dependent services
    echo "$blue""Restarting network...""$reset"
    /etc/init.d/network restart
    echo "$yellow""Waiting for network to stabilize...""$reset"
    sleep 5  # Give network more time to stabilize

    # Check network status
    echo "$blue""Checking network status...""$reset"
    set max_attempts 10
    set attempt 1
    while test $attempt -le $max_attempts
        if ifconfig br-lan > /dev/null 2>&1
            echo "$green""Network is up after $attempt attempts""$reset"
            break
        end
        echo "$yellow""Waiting for network interfaces (attempt $attempt/$max_attempts)...""$reset"
        sleep 1
        set attempt (math $attempt + 1)
    end

    if test $attempt -gt $max_attempts
        echo "$red""WARNING: Network may not be fully initialized. Continuing anyway...""$reset"
    end

    echo "$blue""Reloading firewall...""$reset"
    if /etc/init.d/firewall reload
        echo "$green""Firewall reloaded successfully""$reset"
    else
        echo "$red""WARNING: Firewall reload failed""$reset"
    end

    echo "$blue""Reloading DNS services...""$reset"
    if /etc/init.d/dnsmasq reload
        echo "$green""DNS services reloaded successfully""$reset"
    else
        echo "$red""WARNING: DNS services reload failed""$reset"
    end

    echo "$blue""Restarting SSH server...""$reset"
    if /etc/init.d/dropbear restart
        echo "$green""SSH server restarted successfully""$reset"
    else
        echo "$red""WARNING: SSH server restart failed""$reset"
    end

    echo "$green""All services restarted. You may need to reconnect if network settings changed.""$reset"
    echo "$green""Installation process completed successfully. Log saved to $LOG_FILE""$reset"
end
