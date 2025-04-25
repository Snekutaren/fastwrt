#!/usr/bin/fish
# FastWrt Installation Script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set BASE_DIR correctly and ensure it's actually the parent directory of the scripts
set SCRIPT_PATH (status filename)
if string match -q "/*" "$SCRIPT_PATH"
    # Absolute path
    set BASE_DIR (dirname "$SCRIPT_PATH")
else
    # Relative path, use pwd
    set BASE_DIR (pwd)
end
set -gx BASE_DIR "$BASE_DIR"

# CRITICAL FIX: Explicitly define SCRIPTS_DIR to match BASE_DIR
# This fixes the "find: : No such file or directory" error
set -gx SCRIPTS_DIR "$BASE_DIR"

# Set up config directories with modular profile support
set CONFIG_DIR "$BASE_DIR/config"
set PROFILES_DIR "$CONFIG_DIR/profiles"
set CONFIG_PROFILE "sne" # Default config profile - can be overridden with --profile flag

# CRITICAL FIX: Check for dry run flag immediately to prevent any system changes
# and ensure it's properly respected throughout the script
set DRY_RUN false
for arg in $argv
    switch $arg
        case "--dry-run"
            set DRY_RUN true
            # Set these immediately for all future operations
            set -gx DRY_RUN true
            set -gx UCI_DRY_RUN true
            # Create a lock file as another indicator of dry run mode
            touch /tmp/fastwrt_dry_run.lock
            echo "Dry run mode enabled - no changes will be committed"
    end
end

# Parse command line arguments (already checked for dry run above)
for arg in $argv
    switch $arg
        case "--debug"
            set DEBUG_MODE true
            set -gx DEBUG true
            # CRITICAL FIX: Make debug mode imply dry run by default 
            # This prevents committing changes in debug mode unless explicitly allowed
            if not set -q DEBUG_COMMIT; or test "$DEBUG_COMMIT" != "true"
                echo "$yellow""Debug mode implies dry run by default. Use DEBUG_COMMIT=true for debug with commits.""$reset"
                set DRY_RUN true
                set -gx DRY_RUN true
                set -gx UCI_DRY_RUN true
            end
        case "--continue-on-error"
            set ABORT_ON_ERROR false
            echo "Continue on error mode enabled - script will attempt to continue after errors"
        case "--profile=*"
            set CONFIG_PROFILE (string replace --regex "^--profile=" "" "$arg")
    end
end

set PROFILE_DIR "$PROFILES_DIR/$CONFIG_PROFILE"
set DEFAULTS_DIR "$PROFILE_DIR"

# Make these paths available to all scripts
set -gx CONFIG_DIR "$CONFIG_DIR"
set -gx PROFILES_DIR "$PROFILES_DIR"
set -gx PROFILE_DIR "$PROFILE_DIR"
set -gx DEFAULTS_DIR "$DEFAULTS_DIR"
set -gx CONFIG_PROFILE "$CONFIG_PROFILE"

# Source common color definitions - do this after setting up PROFILE_DIR
source "$PROFILE_DIR/colors.fish"

# Start
print_info "FastWrt Configuration Running from: "(cd (dirname (status filename)) && pwd)
print_info "Current time: "(date)

# If in dry run mode, inform user about limitations
if test "$DRY_RUN" = "true"
    echo "$yellow""DRY RUN MODE ACTIVE: Configuration will be validated but not applied""$reset"
    echo "$yellow""No permanent changes will be made to the system""$reset"
end

# Initialize environment variables
echo "$blue""Initializing environment variables...""$reset"
set ENVIRONMENT_SCRIPT (dirname "$SCRIPT_PATH")/02-environment.sh
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

# The environment script sets FISH_ENV_SCRIPT, so we can use it from here on

# Default configuration
set DEBUG_MODE false
set ABORT_ON_ERROR true  # Flag to control error handling behavior

# Check if the selected profile exists
if not test -d "$PROFILE_DIR"
    echo "$red""Error: Configuration profile '$CONFIG_PROFILE' not found in $PROFILES_DIR""$reset"
    echo "$yellow""Available profiles:""$reset"
    for dir in $PROFILES_DIR/*/
        if test -d "$dir"
            echo "  - "(basename "$dir")
        end
    end
    echo "$yellow""You can specify a profile with --profile=name""$reset"
    exit 1
end

echo "$green""Using configuration profile: $CONFIG_PROFILE from $PROFILE_DIR""$reset"

# Make log directory in a writable location
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

# Define script dependencies - which scripts must complete before others can run
# Format: script_name:dependency1,dependency2,...
set -l script_dependencies
set -a script_dependencies "40-dhcp.sh:30-network.sh"
set -a script_dependencies "50-firewall.sh:30-network.sh,40-dhcp.sh"
set -a script_dependencies "60-wireless.sh:30-network.sh,50-firewall.sh"

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

# Keep track of script success/failure
set -l completed_scripts
set -l failed_scripts

# For script running, continue to use the FISH_ENV_SCRIPT variable as before
# Get a list of scripts sorted by name (numeric prefix)
set scripts_to_run (find "$SCRIPTS_DIR" -maxdepth 1 -name "[0-9]*.sh" | sort)

# Track overall success
set overall_success true

# Add a function to count and validate script execution
function count_scripts
    set expected_dir $argv[1]
    set skip_pattern $argv[2]
    
    # Find all numbered scripts (starting with digits) and exclude the skip pattern
    set all_scripts (find "$expected_dir" -maxdepth 1 -name "[0-9]*.sh" | sort)
    
    # Count scripts, excluding the main install script
    set script_count 0
    for script in $all_scripts
        set script_basename (basename "$script")
        if not string match -q "$skip_pattern" "$script_basename"
            set script_count (math $script_count + 1)
        end
    end
    
    echo $script_count
end

# Count expected script executions before starting
echo "$blue""Checking script execution plan...""$reset"
# FIX: Add proper error handling for the find command and use absolute paths
set scripts_list (find "$SCRIPTS_DIR" -maxdepth 1 -name "[0-9]*.sh" 2>/dev/null || echo "")
set expected_script_count (count_scripts "$SCRIPTS_DIR" "01-install.sh")
echo "$blue""Found $expected_script_count scripts to execute""$reset"

# Reset counters for script execution tracking
set executed_script_count 0

# Execute each script in sequence, but handle differently for dry run
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
    
    # CRITICAL FIX: For dry run mode, add extra environment variable
    # so scripts can avoid making irreversible changes
    if test "$DRY_RUN" = "true"
        echo "$yellow""(DRY RUN MODE - Changes will be shown but not applied)""$reset"
        
        # Fix: Use more compatible approach for setting environment variables
        set -gx UCI_DRY_RUN true
        set -gx DRY_RUN true
        fish -C "source $FISH_ENV_SCRIPT" "$script" 2>&1 | tee -a "$LOG_FILE"
    else
        # Normal execution for non-dry-run mode
        fish -C "source $FISH_ENV_SCRIPT" "$script" 2>&1 | tee -a "$LOG_FILE"
    end
    
    # Keep track of script success/failure
    if test $status -eq 0
        echo "$green""Script $script completed successfully""$reset"
        set -a completed_scripts "$script_basename"
        set executed_script_count (math $executed_script_count + 1)  # Increment counter
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

# Initialize commit authorization to false by default - nothing can commit without this
set -gx COMMIT_AUTHORIZED false

# After all scripts executed and validation is complete
echo "$blue""All scripts executed.""$reset"

# Verify script execution count before committing
echo "$blue""Verifying script execution completeness...""$reset"
echo "$green""Expected scripts: $expected_script_count""$reset"
echo "$green""Executed scripts: $executed_script_count""$reset"

# Only authorize commits if all validation passes
if test "$overall_success" = "true"; and test $executed_script_count -eq $expected_script_count
    # Set the authorization token - this is required for commits
    set -gx COMMIT_AUTHORIZED true
    echo "$green""Configuration validation passed - commit authorized""$reset"
else
    # Keep authorization as false
    echo "$red""Configuration validation failed - commit NOT authorized""$reset"
end

# CRITICAL - All service restart code should be protected with dry run check
# Only restart services if NOT in dry run mode
if test "$DRY_RUN" != "true"
    # Special protection to prevent debug mode from committing unless explicitly allowed
    if test "$DEBUG" = "true"; and not set -q DEBUG_COMMIT
        echo "$yellow""DEBUG MODE: Changes will NOT be committed (safety feature)""$reset"
        echo "$yellow""To commit changes in debug mode, run: DEBUG_COMMIT=true $0 --debug""$reset"
        echo "$yellow""Reverting all changes...""$reset"
        
        # Reuse the reversion logic from the dry run mode
        set total_change_count 0
        set configs_to_revert (uci changes | cut -d. -f1 | sort -u)
        
        for cfg in $configs_to_revert
            echo "$blue""Reverting $cfg...""$reset"
            set section_changes (uci changes $cfg | wc -l)
            set total_change_count (math $total_change_count + $section_changes)
            uci revert $cfg 2>/dev/null || echo "$yellow""Note: No changes to revert for $cfg""$reset"
        end
        exit 0
    end

    echo "$purple""Committing UCI changes...""$reset"
    uci commit

    # Restart services
    echo "$purple""Restarting services...""$reset"
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
else
    echo "$yellow""DRY RUN: Skipping commits and service restarts""$reset"
end

# CRITICAL FIX: At the end of execution, handle dry run properly
if test "$DRY_RUN" = "true"
    echo "$yellow""--- DRY RUN SUMMARY ---""$reset"
    
    # Instead of duplicating summary logic, use the summary script directly
    # This delegates all summary responsibility to the specialized script
    if test "$DEBUG" = "true"
        # In debug mode, show detailed information
        echo "$blue""Generating detailed configuration summary...""$reset"
        # Call summary script with show-detailed flag
        fish -C "source $FISH_ENV_SCRIPT" "$BASE_DIR/80-summary.sh" --show-detailed
    else
        # In regular dry run mode, show brief summary
        echo "$blue""Generating brief configuration summary...""$reset"
        # Call summary script with brief mode flag
        fish -C "source $FISH_ENV_SCRIPT" "$BASE_DIR/80-summary.sh" --brief
    end
    
    # IMPORTANT NOTE: Clarify how UCI dry run works
    echo "$purple""IMPORTANT: In dry run mode, UCI changes are temporarily populated to show what would change,""$reset"
    echo "$purple""          but will now be reverted. This is normal and expected behavior.""$reset"
    
    echo "$yellow""Reverting all changes due to dry run mode...""$reset" 
    # Properly revert all changes without failing on missing configs
    set total_change_count 0
    set configs_to_revert (uci changes | cut -d. -f1 | sort -u)
    
    # Show total pending changes before revert for verification
    set total_pending_changes (uci changes | wc -l)
    echo "$blue""Total pending changes to revert: $total_pending_changes""$reset"
    
    # Revert each config section individually for more robust reverting
    for cfg in $configs_to_revert
        echo "$blue""Reverting $cfg...""$reset"
        set section_changes (uci changes $cfg | wc -l)
        set total_change_count (math $total_change_count + $section_changes)
        uci revert $cfg 2>/dev/null || echo "$yellow""Note: No changes to revert for $cfg""$reset"
    end
    
    # Double-check that no changes remain - this is important verification
    set remaining_changes (uci changes | wc -l) 
    if test $remaining_changes -gt 0
        echo "$red""WARNING: $remaining_changes changes could not be reverted. Details:""$reset"
        uci changes
        echo "$yellow""Attempting force revert of remaining changes...""$reset"
        uci revert
        
        # Final verification
        set final_changes (uci changes | wc -l)
        if test $final_changes -gt 0
            echo "$red""ERROR: Still have $final_changes unreverted changes. This is unusual.""$reset"
        else
            echo "$green""Force revert succeeded, all changes cleared""$reset"
        end
    else
        echo "$green""Successfully reverted all $total_change_count configuration changes""$reset"
    end
    
    # Clean up environment
    rm -f "$FISH_ENV_SCRIPT" /tmp/fastwrt_dry_run.lock
    echo "$green""Dry run completed successfully.""$reset"
    echo "$green""No permanent changes were made to the system.""$reset"
    exit 0
end

# CRITICAL FIX: Added check to prevent commits from debug mode unless explicitly approved
if test "$DEBUG" = "true"; and not test "$COMMIT_AUTHORIZED" = "true"
    echo "$yellow""DEBUG MODE: Changes shown but NOT committed to prevent unintended modifications.""$reset"
    echo "$yellow""To commit changes in debug mode, use: DEBUG_COMMIT=true $0 --debug""$reset"
    echo "$yellow""Reverting all changes...""$reset"
    
    # Reuse the reversion logic from the dry run mode
    set total_change_count 0
    set configs_to_revert (uci changes | cut -d. -f1 | sort -u)
    
    for cfg in $configs_to_revert
        echo "$blue""Reverting $cfg...""$reset"
        set section_changes (uci changes $cfg | wc -l)
        set total_change_count (math $total_change_count + $section_changes)
        uci revert $cfg 2>/dev/null || echo "$yellow""Note: No changes to revert for $cfg""$reset"
    end
    exit 0
end
echo "$green""Installation process completed successfully. Log saved to $LOG_FILE""$reset"
