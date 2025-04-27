#!/usr/bin/fish
# FastWrt Installation Script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set BASE_DIR correctly and ensure it's the parent directory of the scripts
set SCRIPT_PATH (status filename)
if string match -q "/*" "$SCRIPT_PATH"
    set BASE_DIR (dirname "$SCRIPT_PATH")
else
    set BASE_DIR (pwd)
end
set -gx BASE_DIR "$BASE_DIR"
set -gx SCRIPTS_DIR "$BASE_DIR"

# Set up config directories with modular profile support
set CONFIG_DIR "$BASE_DIR/config"
set PROFILES_DIR "$CONFIG_DIR/profiles"
set CONFIG_PROFILE "sne" # Default config profile
set -gx CONFIG_DIR "$CONFIG_DIR"
set -gx PROFILES_DIR "$PROFILES_DIR"
set -gx PROFILE_DIR "$PROFILES_DIR/$CONFIG_PROFILE"
set -gx DEFAULTS_DIR "$PROFILE_DIR"
set -gx CONFIG_PROFILE "$CONFIG_PROFILE"

# Initialize flags
set DRY_RUN false
set DEBUG false
set ABORT_ON_ERROR true
set COMMIT_AUTHORIZED false
set executed_script_count 0
set expected_script_count 0

# Parse command line arguments
for arg in $argv
    switch $arg
        case "--dry-run"
            set DRY_RUN true
            set -gx DRY_RUN true
            set -gx UCI_DRY_RUN true
            touch /tmp/fastwrt_dry_run.lock
            echo "Dry run mode enabled - no changes will be committed"
        case "--debug"
            set DEBUG true
            set -gx DEBUG true
            if not set -q DEBUG_COMMIT; or test "$DEBUG_COMMIT" != "true"
                echo "$yellow""Debug mode implies dry run unless DEBUG_COMMIT=true""$reset"
                set DRY_RUN true
                set -gx DRY_RUN true
                set -gx UCI_DRY_RUN true
            end
        case "--continue-on-error"
            set ABORT_ON_ERROR false
            echo "Continue on error mode enabled"
        case "--profile=*"
            set CONFIG_PROFILE (string replace --regex "^--profile=" "" "$arg")
            set -gx CONFIG_PROFILE "$CONFIG_PROFILE"
            set -gx PROFILE_DIR "$PROFILES_DIR/$CONFIG_PROFILE"
            set -gx DEFAULTS_DIR "$PROFILE_DIR"
    end
end

# Source color definitions
source "$PROFILE_DIR/colors.fish"

# Dry run setup
if test "$DRY_RUN" = "true"
    set -gx UCI_TMP_DIR "/tmp/fastwrt_dryrun_$(date +%s)"
    mkdir -p "$UCI_TMP_DIR"
    set -gx UCI_CONFIG_DIR "$UCI_TMP_DIR"
    if not functions -q uci
        function uci
            if test "$DEBUG" = "true"
                echo "$cyan""DEBUG: Using overridden uci command with path $UCI_TMP_DIR""$reset"
            end
            command uci -c /etc/config -P "$UCI_TMP_DIR" $argv
        end
    end
    echo "$yellow""Dry run mode: UCI changes stored in $UCI_TMP_DIR""$reset"
end

# Start
print_info "FastWrt Configuration Running from: "(cd (dirname (status filename)) && pwd)
print_info "Current time: "(date)
if test "$DRY_RUN" = "true"
    echo "$yellow""DRY RUN MODE ACTIVE: Configuration will be validated but not applied""$reset"
end

# Initialize environment
echo "$blue""Initializing environment variables...""$reset"
set ENVIRONMENT_SCRIPT "$BASE_DIR/02-environment.sh"
if test -f "$ENVIRONMENT_SCRIPT"
    fish "$ENVIRONMENT_SCRIPT"
    if test $status -ne 0
        echo "$red""Failed to initialize environment. Aborting.""$reset"
        exit 1
    end
    echo "$green""Environment initialized successfully""$reset"
else
    echo "$red""Environment script not found at: $ENVIRONMENT_SCRIPT""$reset"
    exit 1
end

# Check profile existence
if not test -d "$PROFILE_DIR"
    echo "$red""Error: Configuration profile '$CONFIG_PROFILE' not found in $PROFILES_DIR""$reset"
    echo "$yellow""Available profiles:""$reset"
    for dir in $PROFILES_DIR/*/
        if test -d "$dir"
            echo "  - "(basename "$dir")
        end
    end
    exit 1
end
echo "$green""Using configuration profile: $CONFIG_PROFILE from $PROFILE_DIR""$reset"

# Set up logging
set LOG_DIR "/tmp/fastwrt_logs"
mkdir -p "$LOG_DIR"
set LOG_FILE "$LOG_DIR/install_"(date +%Y%m%d_%H%M%S)"_$CONFIG_PROFILE.log"
echo "$blue""Logging installation process to $LOG_FILE""$reset"

# Check for root privileges
if test (id -u) -ne 0
    echo "$red""Please run as root""$reset"
    exit 1
end

set CURRENT_SCRIPT (realpath (status filename))

# Define script dependencies
set -l script_dependencies
set -a script_dependencies "40-dhcp.sh:30-network.sh"
set -a script_dependencies "50-firewall.sh:30-network.sh,40-dhcp.sh"
set -a script_dependencies "35-wireless.sh:30-network.sh"
set -a script_dependencies "45-wireguard.sh:30-network.sh"
set -a script_dependencies "70-dropbear.sh:50-firewall.sh"

# Function to check dependencies
function dependencies_met
    set -l script_name $argv[1]
    set -l deps ""
    for dep_entry in $script_dependencies
        if string match -q "$script_name:*" "$dep_entry"
            set deps (string split "," (string split ":" "$dep_entry")[2])
            break
        end
    end
    if test -z "$deps"
        return 0
    end
    for dep in $deps
        if not contains "$dep" $completed_scripts
            echo "$red""Script $script_name depends on $dep which has not completed successfully""$reset"
            return 1
        end
    end
    return 0
end

# Simplified function to revert all UCI changes - direct sequential approach
function revert_all_uci_changes
    echo "$blue""Reverting all UCI changes...""$reset"
    
    # First check if there are any changes to revert
    set total_changes (uci changes | wc -l)
    if test $total_changes -eq 0
        echo "$green""No UCI changes to revert""$reset"
        return 0
    end
    
    echo "$yellow""Found $total_changes pending UCI changes""$reset"
    
    # Simply revert each major configuration category one by one
    echo "$blue""Reverting dhcp changes...""$reset"
    uci revert dhcp
    
    echo "$blue""Reverting network changes...""$reset"
    uci revert network
    
    echo "$blue""Reverting wireless changes...""$reset"
    uci revert wireless
    
    echo "$blue""Reverting firewall changes...""$reset"
    uci revert firewall
    
    echo "$blue""Reverting system changes...""$reset"
    uci revert system
    
    echo "$blue""Reverting dropbear changes...""$reset"
    uci revert dropbear
    
    echo "$blue""Reverting uhttpd changes...""$reset"
    uci revert uhttpd
    
    # Also try other common configurations that might have changes
    uci revert luci 2>/dev/null
    uci revert nlbwmon 2>/dev/null
    uci revert sqm 2>/dev/null
    uci revert statistics 2>/dev/null
    
    # Clean temporary UCI directories as a fallback
    if test -d /tmp/.uci
        rm -rf /tmp/.uci
        echo "$green""Removed /tmp/.uci directory""$reset"
    end
    
    if test -d /var/run/uci
        rm -rf /var/run/uci
        echo "$green""Removed /var/run/uci directory""$reset"
    end
    
    # Final verification
    set final_changes (uci changes | wc -l)
    if test $final_changes -eq 0
        echo "$green""Successfully cleaned up all changes""$reset"
    else
        echo "$yellow""$final_changes changes still remain after cleanup""$reset"
        if test "$DEBUG" = "true"
            echo "$cyan""Remaining changes:""$reset"
            uci changes | head -10
        end
    end
end

# Track script execution
set -l completed_scripts
set -l failed_scripts
set scripts_to_run (find "$SCRIPTS_DIR" -maxdepth 1 -name "[0-9]*.sh" | sort)
set overall_success true

function count_scripts
    set expected_dir $argv[1]
    set skip_pattern $argv[2]
    set all_scripts (find "$expected_dir" -maxdepth 1 -name "[0-9]*.sh" | sort)
    set script_count 0
    for script in $all_scripts
        set script_basename (basename "$script")
        if not string match -q "$skip_pattern" "$script_basename"
            set script_count (math $script_count + 1)
        end
    end
    echo $script_count
end

set expected_script_count (count_scripts "$SCRIPTS_DIR" "01-install.fish")
if test "$DEBUG" = "true"
    echo "$cyan""DEBUG: Scripts to run: $scripts_to_run""$reset"
    echo "$cyan""DEBUG: Expected script count: $expected_script_count""$reset"
end
echo "$blue""Found $expected_script_count scripts to execute""$reset"

# Execute scripts
for script in $scripts_to_run
    if test (realpath "$script") = "$CURRENT_SCRIPT"
        echo "$yellow""Skipping self: $script""$reset"
        continue
    end
    set script_basename (basename "$script")
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
    if test "$DRY_RUN" = "true"
        echo "$yellow""(DRY RUN MODE - Changes will be shown but not applied)""$reset"
    end
    fish "$script" 2>&1 | tee -a "$LOG_FILE"
    if test $status -eq 0
        echo "$green""Script $script completed successfully""$reset"
        set -a completed_scripts "$script_basename"
        set executed_script_count (math $executed_script_count + 1)
    else
        set exit_status $status
        echo "$red""ERROR: Script $script failed with exit code $exit_status""$reset"
        echo "$red""Fix the root cause in $script_basename instead of using fallbacks.""$reset"
        set -a failed_scripts "$script_basename"
        if test "$ABORT_ON_ERROR" = "true"
            set overall_success false
            echo "$red""Aborting due to script failure""$reset"
            break
        end
    end
end

# Verify execution
echo "$blue""Verifying script execution completeness...""$reset"
echo "$green""Expected scripts: $expected_script_count""$reset"
echo "$green""Executed scripts: $executed_script_count""$reset"

# Authorize commits
if test "$overall_success" = "true"
    if test $executed_script_count -eq $expected_script_count
        set -gx COMMIT_AUTHORIZED true
        echo "$green""Configuration validation passed - commit authorized""$reset"
    else
        echo "$red""Configuration validation failed - commit NOT authorized""$reset"
    end
else
    echo "$red""Configuration validation failed - commit NOT authorized""$reset"
end

# Handle commits and service restarts
if test "$DRY_RUN" = "true"
    echo "$yellow""--- DRY RUN SUMMARY ---""$reset"
    
    # Display pending changes summary
    set total_pending_changes (uci changes | wc -l)
    echo "$blue""Total pending changes to discard: $total_pending_changes""$reset"
    
    # Use the simplified revert function
    revert_all_uci_changes
    
    # Clean up temporary files regardless of revert success
    if set -q UCI_TMP_DIR; and test -d "$UCI_TMP_DIR"
        rm -rf "$UCI_TMP_DIR"
        echo "$green""Removed temporary UCI directory $UCI_TMP_DIR""$reset"
    end
    
    # Remove temporary UCI function definition
    set uci_override_exists (functions -q uci)
    if test "$uci_override_exists" = "true"
        functions -e uci
        echo "$green""Restored original UCI command""$reset"
    end
    
    # Final cleanup of any lock files
    rm -f /tmp/fastwrt_dry_run.lock
    echo "$green""Dry run completed successfully. No permanent changes made.""$reset"
else if test "$DEBUG" = "true"
    if test "$COMMIT_AUTHORIZED" != "true"
        echo "$yellow""DEBUG MODE: Changes not committed to prevent unintended modifications.""$reset"
        echo "$yellow""To commit in debug mode, use: DEBUG_COMMIT=true $0 --debug""$reset"
        revert_all_uci_changes
        echo "$green""Installation process completed successfully. Log saved to $LOG_FILE""$reset"
    else
        set pre_commit_changes (uci changes | wc -l)
        if test $pre_commit_changes -eq 0
            echo "$yellow""No UCI changes to commit""$reset"
        else
            echo "$blue""Committing $pre_commit_changes UCI changes...""$reset"
            uci commit
        end
        echo "$purple""Restarting services...""$reset"
        echo "$blue""Restarting network...""$reset"
        /etc/init.d/network restart
        echo "$yellow""Waiting for network to stabilize...""$reset"
        sleep 3
        set max_attempts 10
        set attempt 1
        while test $attempt -le $max_attempts
            if ifconfig br-lan > /dev/null 2>&1
                echo "$green""Network is up after $attempt attempts""$reset"
                break
            end
            echo "$yellow""Waiting for network (attempt $attempt/$max_attempts)...""$reset"
            sleep 1
            set attempt (math $attempt + 1)
        end
        if test $attempt -gt $max_attempts
            echo "$red""WARNING: Network may not be fully initialized""$reset"
        end
        echo "$blue""Reloading firewall and DNS services...""$reset"
        set service_status true
        if not /etc/init.d/firewall reload
            echo "$red""WARNING: Firewall reload failed""$reset"
            set service_status false
        end
        if not /etc/init.d/dnsmasq reload
            echo "$red""WARNING: DNS services reload failed""$reset"
            set service_status false
        end
        if test "$service_status" = "true"
            echo "$green""Firewall and DNS services reloaded successfully""$reset"
        end
        echo "$blue""Restarting SSH server...""$reset"
        if /etc/init.d/dropbear restart
            echo "$green""SSH server restarted successfully""$reset"
        else
            echo "$red""WARNING: SSH server restart failed""$reset"
        end
        echo "$green""Installation process completed successfully. Log saved to $LOG_FILE""$reset"
    end
else if test "$COMMIT_AUTHORIZED" = "true"
    # Count changes before committing
    set pre_commit_changes (uci changes | wc -l)
    if test $pre_commit_changes -eq 0
        echo "$yellow""No UCI changes to commit""$reset"
    else
        echo "$blue""Committing $pre_commit_changes UCI changes...""$reset"
        uci commit
    end
    
    # Restart services section - unchanged
    echo "$purple""Restarting services...""$reset"
    echo "$blue""Restarting network...""$reset"
    /etc/init.d/network restart
    echo "$yellow""Waiting for network to stabilize...""$reset"
    sleep 3
    set max_attempts 10
    set attempt 1
    while test $attempt -le $max_attempts
        if ifconfig br-lan > /dev/null 2>&1
            echo "$green""Network is up after $attempt attempts""$reset"
            break
        end
        echo "$yellow""Waiting for network (attempt $attempt/$max_attempts)...""$reset"
        sleep 1
        set attempt (math $attempt + 1)
    end
    if test $attempt -gt $max_attempts
        echo "$red""WARNING: Network may not be fully initialized""$reset"
    end
    echo "$blue""Reloading firewall and DNS services...""$reset"
    set service_status true
    if not /etc/init.d/firewall reload
        echo "$red""WARNING: Firewall reload failed""$reset"
        set service_status false
    end
    if not /etc/init.d/dnsmasq reload
        echo "$red""WARNING: DNS services reload failed""$reset"
        set service_status false
    end
    if test "$service_status" = "true"
        echo "$green""Firewall and DNS services reloaded successfully""$reset"
    end
    echo "$blue""Restarting SSH server...""$reset"
    if /etc/init.d/dropbear restart
        echo "$green""SSH server restarted successfully""$reset"
    else
        echo "$red""WARNING: SSH server restart failed""$reset"
    end
    echo "$green""Installation process completed successfully. Log saved to $LOG_FILE""$reset"
end